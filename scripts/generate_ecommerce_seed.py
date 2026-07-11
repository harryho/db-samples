#!/usr/bin/env python3
"""Regenerate the ecommerce sample seed data for every dialect.

Reads the Northwind seed data out of pgsql/northwind.sql, maps it onto the
modern e-commerce model once, then renders it per dialect:

  - pgsql/ecommerce.sql  (rewrites between "-- SEED:BEGIN" / "-- SEED:END")
  - mysql/ecommerce.sql  (rewrites between the same markers)
  - mongo/ecommerce/*.json  (document model: JSON arrays for mongoimport)

Deterministic (same input -> same output), stdlib only.
Usage: python3 scripts/generate_ecommerce_seed.py
"""

import json
import re
import sys
import unicodedata
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NORTHWIND_SQL = ROOT / "pgsql" / "northwind.sql"
PGSQL_OUT = ROOT / "pgsql" / "ecommerce.sql"
MYSQL_OUT = ROOT / "mysql" / "ecommerce.sql"
MONGO_OUT_DIR = ROOT / "mongo" / "ecommerce"

SEED_BEGIN = "-- SEED:BEGIN"
SEED_END = "-- SEED:END"

# Shared placeholder in bcrypt format; not a real credential.
PASSWORD_HASH = "$2b$12$sampledatasampledatasuXW9dTIWkKO3RhcaCzD9NQBnmWkVse1u"

PROVIDERS = ["card", "paypal", "bank_transfer"]
CENT = Decimal("0.01")

COUNTRY_CODES = {
    "Argentina": "AR", "Australia": "AU", "Austria": "AT", "Belgium": "BE",
    "Brazil": "BR", "Canada": "CA", "Denmark": "DK", "Finland": "FI",
    "France": "FR", "Germany": "DE", "Ireland": "IE", "Italy": "IT",
    "Japan": "JP", "Mexico": "MX", "Netherlands": "NL", "Norway": "NO",
    "Poland": "PL", "Portugal": "PT", "Singapore": "SG", "Spain": "ES",
    "Sweden": "SE", "Switzerland": "CH", "UK": "GB", "USA": "US",
    "Venezuela": "VE",
}

# Shared SQL insert layout: (table, section comment, column list).
SQL_TABLES = [
    ("users", "users (from Northwind customers)",
     ["user_id", "email", "password_hash", "first_name", "last_name", "company_name", "phone"]),
    ("addresses", "addresses (one default per user)",
     ["user_id", "label", "line1", "city", "region", "postal_code", "country_code",
      "is_default_shipping", "is_default_billing"]),
    ("categories", "categories",
     ["category_id", "name", "slug", "description"]),
    ("products", "products (from Northwind products)",
     ["product_id", "category_id", "name", "slug", "description", "is_active"]),
    ("product_variants", "product_variants (one default variant per product)",
     ["variant_id", "product_id", "sku", "name", "price", "is_active"]),
    ("product_images", "product_images (placeholder URLs)",
     ["product_id", "url", "alt_text", "sort_order"]),
    ("inventory", "inventory (deterministic synthetic stock)",
     ["variant_id", "quantity_on_hand"]),
    ("inventory_movements", "inventory_movements (opening restock, ledger == snapshot)",
     ["variant_id", "quantity_delta", "reason"]),
    ("carriers", "carriers (from Northwind shippers)",
     ["carrier_id", "name", "phone"]),
    ("orders", "orders (from Northwind sales orders)",
     ["order_id", "user_id", "order_number", "status", "subtotal", "discount_total",
      "shipping_total", "grand_total", "ship_name", "ship_line1", "ship_city",
      "ship_region", "ship_postal_code", "ship_country_code", "ordered_at"]),
    ("order_items", "order_items (from Northwind order details)",
     ["order_id", "variant_id", "product_name", "sku", "unit_price", "qty", "discount"]),
    ("order_status_history", "order_status_history (derived from order/ship dates)",
     ["order_id", "status", "changed_at"]),
    ("payments", "payments",
     ["order_id", "amount", "provider", "provider_ref", "status", "created_at"]),
    ("shipments", "shipments (delivered orders only)",
     ["order_id", "carrier_id", "tracking_number", "shipped_at", "delivered_at"]),
    ("carts", "carts (synthesized; Northwind has no cart concept)",
     ["cart_id", "user_id", "session_token", "status"]),
    ("cart_items", "cart_items",
     ["cart_id", "variant_id", "qty"]),
]


# ---------------------------------------------------------------- parsing

def parse_value_list(text, pos):
    """Parse a SQL value list; pos points just past the opening '('."""
    vals, buf, depth, in_str, i = [], [], 0, False, pos
    while True:
        ch = text[i]
        if in_str:
            buf.append(ch)
            if ch == "'":
                if text[i + 1] == "'":
                    buf.append("'")
                    i += 1
                else:
                    in_str = False
        elif ch == "'":
            in_str = True
            buf.append(ch)
        elif ch == "(":
            depth += 1
            buf.append(ch)
        elif ch == ")":
            if depth == 0:
                vals.append("".join(buf).strip())
                return [decode(v) for v in vals]
            depth -= 1
            buf.append(ch)
        elif ch == "," and depth == 0:
            vals.append("".join(buf).strip())
            buf = []
        else:
            buf.append(ch)
        i += 1


def decode(token):
    if token.upper() == "NULL":
        return None
    if token.startswith("N'"):
        token = token[1:]
    if token.startswith("'"):
        return token[1:-1].replace("''", "'")
    return token  # numeric literal, kept as string


def parse_table(sql_text, table):
    pattern = re.compile(r"INSERT INTO %s\s*\([^)]*\)\s*VALUES\s*\(" % table)
    return [parse_value_list(sql_text, m.end()) for m in pattern.finditer(sql_text)]


# ---------------------------------------------------------------- helpers

def parse_ts(raw):
    # '20060704 00:00:00.000' -> aware datetime (UTC)
    return datetime.strptime(raw.split(" ")[0], "%Y%m%d").replace(tzinfo=timezone.utc)


def slugify(name):
    ascii_name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", ascii_name.lower()).strip("-") or "item"


def email_local(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z]", "", s) or "user"


def name_parts(contactname):
    if contactname and ", " in contactname:
        last, first = contactname.split(", ", 1)
        return first.strip(), last.strip()
    if contactname:
        return contactname.strip(), "Customer"
    return "Sample", "Customer"


def country_code(name):
    if name is None:
        return None
    if name not in COUNTRY_CODES:
        sys.exit(f"ERROR: no ISO code for country {name!r}; add it to COUNTRY_CODES")
    return COUNTRY_CODES[name]


def cents(v):
    return Decimal(v).quantize(CENT, rounding=ROUND_HALF_UP)


def order_status(orderid, shipped):
    if shipped is not None:
        return "delivered"
    if orderid % 11 == 0:
        return "cancelled"
    if orderid % 7 == 0:
        return "pending"
    return "processing"


# ---------------------------------------------------------------- dataset

def build_dataset(nw):
    """Map Northwind rows onto the e-commerce model, dialect-neutral."""
    customers = parse_table(nw, "Customer")
    categories = parse_table(nw, "Category")
    products = parse_table(nw, "Product")
    shippers = parse_table(nw, "Shipper")
    orders = parse_table(nw, "SalesOrder")
    details = parse_table(nw, "OrderDetail")
    assert len(customers) == 91 and len(products) == 77 and len(orders) == 830, \
        f"unexpected northwind row counts: {len(customers)}/{len(products)}/{len(orders)}"

    ds = {t: [] for t, _c, _cols in SQL_TABLES}

    # users + addresses (custid -> user_id)
    used_emails = set()
    for custid, company, contact, _title, addr, city, region, postal, country, phone, _fax in customers:
        first, last = name_parts(contact)
        base = f"{email_local(first)}.{email_local(last)}"
        email, n = f"{base}@example.com", 1
        while email in used_emails:
            n += 1
            email = f"{base}{n}@example.com"
        used_emails.add(email)
        ds["users"].append({
            "user_id": int(custid), "email": email, "password_hash": PASSWORD_HASH,
            "first_name": first, "last_name": last, "company_name": company, "phone": phone,
        })
        ds["addresses"].append({
            "user_id": int(custid), "label": "Primary", "line1": addr or "N/A",
            "city": city or "N/A", "region": region, "postal_code": postal,
            "country_code": country_code(country),
            "is_default_shipping": True, "is_default_billing": True,
        })

    # categories
    for cid, name, desc in categories:
        ds["categories"].append({
            "category_id": int(cid), "name": name, "slug": slugify(name), "description": desc,
        })

    # products / variants / images / inventory (+ opening restock movements)
    used_slugs = set()
    active_variants = []
    for pid, name, _supplier, catid, price, discontinued in products:
        pid = int(pid)
        slug, n = slugify(name), 1
        while slug in used_slugs:
            n += 1
            slug = f"{slugify(name)}-{n}"
        used_slugs.add(slug)
        active = discontinued == "0"
        if active:
            active_variants.append(pid)
        ds["products"].append({
            "product_id": pid, "category_id": int(catid), "name": name, "slug": slug,
            "description": f"Sample description for {name}.", "is_active": active,
        })
        ds["product_variants"].append({
            "variant_id": pid, "product_id": pid, "sku": f"SKU-{pid:04d}",
            "name": "Default", "price": cents(price), "is_active": active,
        })
        ds["product_images"].append({
            "product_id": pid, "url": f"https://picsum.photos/seed/product-{pid}/600/400",
            "alt_text": name, "sort_order": 0,
        })
        qoh = ((pid * 37) % 140) + 10 if active else 0
        ds["inventory"].append({"variant_id": pid, "quantity_on_hand": qoh})
        if qoh > 0:
            ds["inventory_movements"].append(
                {"variant_id": pid, "quantity_delta": qoh, "reason": "restock"})

    # carriers
    for sid, name, phone in shippers:
        ds["carriers"].append({"carrier_id": int(sid), "name": name, "phone": phone})

    # order lines grouped by order
    product_name = {int(p[0]): p[1] for p in products}
    lines_by_order = {}
    for oid, pid, price, qty, disc in details:
        key = (int(oid), int(pid))
        if key in lines_by_order.setdefault(int(oid), {}):
            sys.exit(f"ERROR: duplicate order line {key}")
        d = Decimal(disc)
        if not (0 <= d <= 1):
            sys.exit(f"ERROR: discount out of range on {key}: {d}")
        lines_by_order[int(oid)][key] = (Decimal(price), int(qty), d)

    # orders + items + history + payments + shipments
    for (oid, custid, _emp, odate, _req, sdate, shipperid, freight, sname, saddr,
         scity, sregion, spostal, scountry) in orders:
        oid = int(oid)
        lines = lines_by_order.get(oid)
        if not lines:
            sys.exit(f"ERROR: order {oid} has no line items")
        ordered = parse_ts(odate)
        shipped = parse_ts(sdate) if sdate is not None else None
        status = order_status(oid, shipped)
        subtotal = sum((up * qty for up, qty, _d in lines.values()), Decimal(0)).quantize(
            CENT, rounding=ROUND_HALF_UP)
        line_sum = sum(((up * qty * (1 - d)).quantize(CENT, rounding=ROUND_HALF_UP)
                        for up, qty, d in lines.values()), Decimal(0))
        discount_total = subtotal - line_sum
        shipping = cents(freight or "0")
        grand = subtotal - discount_total + shipping
        ds["orders"].append({
            "order_id": oid, "user_id": int(custid), "order_number": f"ORD-{oid}",
            "status": status, "subtotal": subtotal, "discount_total": discount_total,
            "shipping_total": shipping, "grand_total": grand, "ship_name": sname,
            "ship_line1": saddr, "ship_city": scity, "ship_region": sregion,
            "ship_postal_code": spostal, "ship_country_code": country_code(scountry),
            "ordered_at": ordered,
        })
        for (_o, pid), (up, qty, d) in sorted(lines.items()):
            ds["order_items"].append({
                "order_id": oid, "variant_id": pid, "product_name": product_name[pid],
                "sku": f"SKU-{pid:04d}", "unit_price": cents(up), "qty": qty, "discount": d,
            })
        ds["order_status_history"].append(
            {"order_id": oid, "status": "pending", "changed_at": ordered})
        if status in ("processing", "delivered"):
            paid_at = ordered + timedelta(hours=1)
            ds["order_status_history"].append(
                {"order_id": oid, "status": "paid", "changed_at": paid_at})
            ds["payments"].append({
                "order_id": oid, "amount": grand, "provider": PROVIDERS[oid % 3],
                "provider_ref": f"ref_{oid}", "status": "captured", "created_at": paid_at,
            })
        elif status == "pending":
            ds["payments"].append({
                "order_id": oid, "amount": grand, "provider": PROVIDERS[oid % 3],
                "provider_ref": f"ref_{oid}", "status": "pending", "created_at": ordered,
            })
        elif status == "cancelled":
            ds["order_status_history"].append(
                {"order_id": oid, "status": "cancelled", "changed_at": ordered + timedelta(days=1)})
        if status == "delivered":
            delivered = shipped + timedelta(days=3)
            ds["order_status_history"].append(
                {"order_id": oid, "status": "shipped", "changed_at": shipped})
            ds["order_status_history"].append(
                {"order_id": oid, "status": "delivered", "changed_at": delivered})
            ds["shipments"].append({
                "order_id": oid, "carrier_id": int(shipperid),
                "tracking_number": f"TRK-{oid}-{shipperid}",
                "shipped_at": shipped, "delivered_at": delivered,
            })

    # carts: users 1..10, deterministic active variants
    for i in range(1, 11):
        token = str(uuid.uuid5(uuid.NAMESPACE_URL, f"db-samples-ecommerce-cart-{i}"))
        ds["carts"].append({"cart_id": i, "user_id": i, "session_token": token, "status": "active"})
        for k in range(1 + (i % 3)):
            variant = active_variants[(i * 7 + k * 11) % len(active_variants)]
            ds["cart_items"].append({"cart_id": i, "variant_id": variant, "qty": (i + k) % 3 + 1})

    return ds


# ---------------------------------------------------------------- SQL rendering

def sql_value(v, dialect):
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, datetime):
        base = v.strftime("%Y-%m-%d %H:%M:%S")
        # MySQL sessions load with time_zone='+00:00'; PostgreSQL gets an
        # explicit offset.
        return f"'{base}+00'" if dialect == "pgsql" else f"'{base}'"
    if isinstance(v, (int, Decimal)):
        return str(v)
    assert "\\" not in v, f"backslash in seed string not supported: {v!r}"
    return "'" + v.replace("'", "''") + "'"


def render_sql(ds, dialect, batch=100):
    out = []
    for table, comment, columns in SQL_TABLES:
        rows = ds[table]
        if not rows:
            continue
        out.append("")
        out.append(f"-- {comment} ({len(rows)} rows)")
        rendered = [[sql_value(r[c], dialect) for c in columns] for r in rows]
        for i in range(0, len(rendered), batch):
            out.append(f"INSERT INTO {table} ({', '.join(columns)}) VALUES")
            chunk = rendered[i:i + batch]
            out.append(",\n".join("  (" + ", ".join(r) + ")" for r in chunk) + ";")
    return "\n-- (generated by scripts/generate_ecommerce_seed.py - do not edit by hand)\n" \
        + "\n".join(out) + "\n"


def splice(path, seed):
    text = path.read_text(encoding="utf-8")
    begin = text.index(SEED_BEGIN) + len(SEED_BEGIN)
    end = text.index(SEED_END)
    path.write_text(text[:begin] + seed + text[end:], encoding="utf-8")


# ---------------------------------------------------------------- Mongo rendering

def mdate(dt):
    return {"$date": dt.strftime("%Y-%m-%dT%H:%M:%SZ")}


def mmoney(v):
    return float(v)


def render_mongo(ds, outdir):
    outdir.mkdir(parents=True, exist_ok=True)

    addr_by_user = {}
    for a in ds["addresses"]:
        addr_by_user.setdefault(a["user_id"], []).append({
            "label": a["label"], "line1": a["line1"], "city": a["city"],
            "region": a["region"], "postalCode": a["postal_code"],
            "countryCode": a["country_code"],
            "isDefaultShipping": a["is_default_shipping"],
            "isDefaultBilling": a["is_default_billing"],
        })
    users = [{
        "userId": u["user_id"], "email": u["email"], "passwordHash": u["password_hash"],
        "firstName": u["first_name"], "lastName": u["last_name"],
        "companyName": u["company_name"], "phone": u["phone"], "isActive": True,
        "addresses": addr_by_user.get(u["user_id"], []),
    } for u in ds["users"]]

    categories = [{
        "categoryId": c["category_id"], "name": c["name"], "slug": c["slug"],
        "description": c["description"],
    } for c in ds["categories"]]
    cat_name = {c["category_id"]: c["name"] for c in ds["categories"]}

    qoh = {i["variant_id"]: i["quantity_on_hand"] for i in ds["inventory"]}
    variants_by_product, images_by_product = {}, {}
    for v in ds["product_variants"]:
        variants_by_product.setdefault(v["product_id"], []).append({
            "variantId": v["variant_id"], "sku": v["sku"], "name": v["name"],
            "price": mmoney(v["price"]), "currency": "USD", "isActive": v["is_active"],
            "quantityOnHand": qoh.get(v["variant_id"], 0),
        })
    for im in ds["product_images"]:
        images_by_product.setdefault(im["product_id"], []).append({
            "url": im["url"], "altText": im["alt_text"], "sortOrder": im["sort_order"],
        })
    products = [{
        "productId": p["product_id"], "categoryId": p["category_id"],
        "categoryName": cat_name[p["category_id"]], "name": p["name"], "slug": p["slug"],
        "description": p["description"], "isActive": p["is_active"],
        "images": images_by_product.get(p["product_id"], []),
        "variants": variants_by_product.get(p["product_id"], []),
    } for p in ds["products"]]

    carriers = [{
        "carrierId": c["carrier_id"], "name": c["name"], "phone": c["phone"],
    } for c in ds["carriers"]]
    carrier_name = {c["carrier_id"]: c["name"] for c in ds["carriers"]}

    items_by_order, hist_by_order = {}, {}
    pay_by_order, ship_by_order = {}, {}
    for it in ds["order_items"]:
        line_total = (it["unit_price"] * it["qty"] * (1 - it["discount"])).quantize(
            CENT, rounding=ROUND_HALF_UP)
        items_by_order.setdefault(it["order_id"], []).append({
            "variantId": it["variant_id"], "productName": it["product_name"],
            "sku": it["sku"], "unitPrice": mmoney(it["unit_price"]), "qty": it["qty"],
            "discount": float(it["discount"]), "lineTotal": mmoney(line_total),
        })
    for h in ds["order_status_history"]:
        hist_by_order.setdefault(h["order_id"], []).append(
            {"status": h["status"], "changedAt": mdate(h["changed_at"])})
    for p in ds["payments"]:
        pay_by_order[p["order_id"]] = {
            "amount": mmoney(p["amount"]), "currency": "USD", "provider": p["provider"],
            "providerRef": p["provider_ref"], "status": p["status"],
            "createdAt": mdate(p["created_at"]),
        }
    for s in ds["shipments"]:
        ship_by_order[s["order_id"]] = {
            "carrierId": s["carrier_id"], "carrierName": carrier_name[s["carrier_id"]],
            "trackingNumber": s["tracking_number"], "shippedAt": mdate(s["shipped_at"]),
            "deliveredAt": mdate(s["delivered_at"]),
        }
    orders = []
    for o in ds["orders"]:
        doc = {
            "orderId": o["order_id"], "orderNumber": o["order_number"],
            "userId": o["user_id"], "status": o["status"], "currency": "USD",
            "subtotal": mmoney(o["subtotal"]), "discountTotal": mmoney(o["discount_total"]),
            "shippingTotal": mmoney(o["shipping_total"]), "grandTotal": mmoney(o["grand_total"]),
            "shipTo": {
                "name": o["ship_name"], "line1": o["ship_line1"], "city": o["ship_city"],
                "region": o["ship_region"], "postalCode": o["ship_postal_code"],
                "countryCode": o["ship_country_code"],
            },
            "orderedAt": mdate(o["ordered_at"]),
            "items": items_by_order[o["order_id"]],
            "statusHistory": hist_by_order[o["order_id"]],
        }
        if o["order_id"] in pay_by_order:
            doc["payment"] = pay_by_order[o["order_id"]]
        if o["order_id"] in ship_by_order:
            doc["shipment"] = ship_by_order[o["order_id"]]
        orders.append(doc)

    ci_by_cart = {}
    for ci in ds["cart_items"]:
        ci_by_cart.setdefault(ci["cart_id"], []).append(
            {"variantId": ci["variant_id"], "qty": ci["qty"]})
    carts = [{
        "cartId": c["cart_id"], "userId": c["user_id"], "sessionToken": c["session_token"],
        "status": c["status"], "items": ci_by_cart.get(c["cart_id"], []),
    } for c in ds["carts"]]

    collections = {
        "users": users, "categories": categories, "products": products,
        "carriers": carriers, "orders": orders, "carts": carts,
    }
    for name, docs in collections.items():
        (outdir / f"{name}.json").write_text(
            json.dumps(docs, ensure_ascii=False, separators=(",", ":")) + "\n",
            encoding="utf-8")
    return {name: len(docs) for name, docs in collections.items()}


# ---------------------------------------------------------------- main

def main():
    ds = build_dataset(NORTHWIND_SQL.read_text(encoding="utf-8"))
    splice(PGSQL_OUT, render_sql(ds, "pgsql"))
    splice(MYSQL_OUT, render_sql(ds, "mysql"))
    counts = render_mongo(ds, MONGO_OUT_DIR)
    print(f"OK: {len(ds['users'])} users, {len(ds['orders'])} orders, "
          f"{len(ds['order_items'])} order items -> pgsql, mysql, mongo "
          f"({', '.join(f'{k}:{v}' for k, v in counts.items())})")


if __name__ == "__main__":
    main()
