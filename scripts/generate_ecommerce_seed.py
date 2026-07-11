#!/usr/bin/env python3
"""Regenerate the seed-data section of pgsql/ecommerce.sql.

Reads the Northwind seed data out of pgsql/northwind.sql, maps it onto the
modern e-commerce schema, and rewrites everything between the
"-- SEED:BEGIN" and "-- SEED:END" markers in pgsql/ecommerce.sql.

Deterministic (same input -> same output), stdlib only.
Usage: python3 scripts/generate_ecommerce_seed.py
"""

import re
import sys
import unicodedata
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NORTHWIND_SQL = ROOT / "pgsql" / "northwind.sql"
ECOMMERCE_SQL = ROOT / "pgsql" / "ecommerce.sql"

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


# ---------------------------------------------------------------- rendering

def q(v):
    if v is None:
        return "NULL"
    return "'" + str(v).replace("'", "''") + "'"


def money(v):
    return str(Decimal(v).quantize(CENT, rounding=ROUND_HALF_UP))


def parse_ts(raw):
    # '20060704 00:00:00.000' -> aware datetime (UTC)
    return datetime.strptime(raw.split(" ")[0], "%Y%m%d").replace(tzinfo=timezone.utc)


def ts(dt):
    return "'" + dt.strftime("%Y-%m-%d %H:%M:%S+00") + "'"


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


def emit(out, comment, table, columns, rows, batch=100):
    """Append multi-row INSERT statements (batches of `batch`) to out."""
    if not rows:
        return
    out.append("")
    out.append(f"-- {comment} ({len(rows)} rows)")
    for i in range(0, len(rows), batch):
        out.append(f"INSERT INTO {table} ({', '.join(columns)}) VALUES")
        chunk = rows[i:i + batch]
        out.append(",\n".join("  (" + ", ".join(r) + ")" for r in chunk) + ";")


def order_status(orderid, shipped):
    if shipped is not None:
        return "delivered"
    if orderid % 11 == 0:
        return "cancelled"
    if orderid % 7 == 0:
        return "pending"
    return "processing"


# ---------------------------------------------------------------- main

def main():
    nw = NORTHWIND_SQL.read_text(encoding="utf-8")
    customers = parse_table(nw, "Customer")
    categories = parse_table(nw, "Category")
    products = parse_table(nw, "Product")
    shippers = parse_table(nw, "Shipper")
    orders = parse_table(nw, "SalesOrder")
    details = parse_table(nw, "OrderDetail")
    assert len(customers) == 91 and len(products) == 77 and len(orders) == 830, \
        f"unexpected northwind row counts: {len(customers)}/{len(products)}/{len(orders)}"

    out = []

    # users + addresses (custid -> user_id)
    used_emails, user_rows, addr_rows = set(), [], []
    for custid, company, contact, _title, addr, city, region, postal, country, phone, _fax in customers:
        first, last = name_parts(contact)
        base = f"{email_local(first)}.{email_local(last)}"
        email, n = f"{base}@example.com", 1
        while email in used_emails:
            n += 1
            email = f"{base}{n}@example.com"
        used_emails.add(email)
        user_rows.append([custid, q(email), q(PASSWORD_HASH), q(first), q(last), q(company), q(phone)])
        addr_rows.append([custid, q("Primary"), q(addr or "N/A"), q(city or "N/A"), q(region),
                          q(postal), q(country_code(country)), "true", "true"])
    emit(out, "users (from Northwind customers)", "users",
         ["user_id", "email", "password_hash", "first_name", "last_name", "company_name", "phone"],
         user_rows)
    emit(out, "addresses (one default per user)", "addresses",
         ["user_id", "label", "line1", "city", "region", "postal_code", "country_code",
          "is_default_shipping", "is_default_billing"],
         addr_rows)

    # categories
    cat_rows = [[cid, q(name), q(slugify(name)), q(desc)] for cid, name, desc in categories]
    emit(out, "categories", "categories", ["category_id", "name", "slug", "description"], cat_rows)

    # products / variants / images / inventory (+ opening restock movements)
    used_slugs = set()
    prod_rows, var_rows, img_rows, inv_rows, mov_rows = [], [], [], [], []
    active_variants = []
    for pid, name, _supplier, catid, price, discontinued in products:
        slug, n = slugify(name), 1
        while slug in used_slugs:
            n += 1
            slug = f"{slugify(name)}-{n}"
        used_slugs.add(slug)
        active = discontinued == "0"
        if active:
            active_variants.append(int(pid))
        prod_rows.append([pid, catid, q(name), q(slug), q(f"Sample description for {name}."),
                          "true" if active else "false"])
        var_rows.append([pid, pid, q(f"SKU-{int(pid):04d}"), q("Default"), money(price),
                         "true" if active else "false"])
        img_rows.append([pid, q(f"https://picsum.photos/seed/product-{pid}/600/400"), q(name), "0"])
        qoh = ((int(pid) * 37) % 140) + 10 if active else 0
        inv_rows.append([pid, str(qoh)])
        if qoh > 0:
            mov_rows.append([pid, str(qoh), q("restock")])
    emit(out, "products (from Northwind products)", "products",
         ["product_id", "category_id", "name", "slug", "description", "is_active"], prod_rows)
    emit(out, "product_variants (one default variant per product)", "product_variants",
         ["variant_id", "product_id", "sku", "name", "price", "is_active"], var_rows)
    emit(out, "product_images (placeholder URLs)", "product_images",
         ["product_id", "url", "alt_text", "sort_order"], img_rows)
    emit(out, "inventory (deterministic synthetic stock)", "inventory",
         ["variant_id", "quantity_on_hand"], inv_rows)
    emit(out, "inventory_movements (opening restock, ledger == snapshot)", "inventory_movements",
         ["variant_id", "quantity_delta", "reason"], mov_rows)

    # carriers
    car_rows = [[sid, q(name), q(phone)] for sid, name, phone in shippers]
    emit(out, "carriers (from Northwind shippers)", "carriers",
         ["carrier_id", "name", "phone"], car_rows)

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
    ord_rows, item_rows, hist_rows, pay_rows, ship_rows = [], [], [], [], []
    for (oid, custid, _emp, odate, _req, sdate, shipperid, freight, sname, saddr,
         scity, sregion, spostal, scountry) in orders:
        oid_i = int(oid)
        lines = lines_by_order.get(oid_i)
        if not lines:
            sys.exit(f"ERROR: order {oid_i} has no line items")
        ordered = parse_ts(odate)
        shipped = parse_ts(sdate) if sdate is not None else None
        status = order_status(oid_i, shipped)
        subtotal = sum((up * qty for up, qty, _d in lines.values()), Decimal(0)).quantize(CENT, rounding=ROUND_HALF_UP)
        line_sum = sum(((up * qty * (1 - d)).quantize(CENT, rounding=ROUND_HALF_UP)
                        for up, qty, d in lines.values()), Decimal(0))
        discount_total = subtotal - line_sum
        shipping = Decimal(freight or "0").quantize(CENT, rounding=ROUND_HALF_UP)
        grand = subtotal - discount_total + shipping
        ord_rows.append([oid, custid, q(f"ORD-{oid_i}"), q(status), str(subtotal),
                         str(discount_total), str(shipping), str(grand), q(sname), q(saddr),
                         q(scity), q(sregion), q(spostal), q(country_code(scountry)), ts(ordered)])
        for (_o, pid), (up, qty, d) in sorted(lines.items()):
            item_rows.append([oid, str(pid), q(product_name[pid]), q(f"SKU-{pid:04d}"),
                              str(up.quantize(CENT, rounding=ROUND_HALF_UP)), str(qty), str(d)])
        hist_rows.append([oid, q("pending"), ts(ordered)])
        if status in ("processing", "delivered"):
            paid_at = ordered + timedelta(hours=1)
            hist_rows.append([oid, q("paid"), ts(paid_at)])
            pay_rows.append([oid, str(grand), q(PROVIDERS[oid_i % 3]), q(f"ref_{oid_i}"),
                             q("captured"), ts(paid_at)])
        elif status == "pending":
            pay_rows.append([oid, str(grand), q(PROVIDERS[oid_i % 3]), q(f"ref_{oid_i}"),
                             q("pending"), ts(ordered)])
        elif status == "cancelled":
            hist_rows.append([oid, q("cancelled"), ts(ordered + timedelta(days=1))])
        if status == "delivered":
            delivered = shipped + timedelta(days=3)
            hist_rows.append([oid, q("shipped"), ts(shipped)])
            hist_rows.append([oid, q("delivered"), ts(delivered)])
            ship_rows.append([oid, shipperid, q(f"TRK-{oid_i}-{shipperid}"),
                              ts(shipped), ts(delivered)])
    emit(out, "orders (from Northwind sales orders)", "orders",
         ["order_id", "user_id", "order_number", "status", "subtotal", "discount_total",
          "shipping_total", "grand_total", "ship_name", "ship_line1", "ship_city",
          "ship_region", "ship_postal_code", "ship_country_code", "ordered_at"], ord_rows)
    emit(out, "order_items (from Northwind order details)", "order_items",
         ["order_id", "variant_id", "product_name", "sku", "unit_price", "qty", "discount"],
         item_rows)
    emit(out, "order_status_history (derived from order/ship dates)", "order_status_history",
         ["order_id", "status", "changed_at"], hist_rows)
    emit(out, "payments", "payments",
         ["order_id", "amount", "provider", "provider_ref", "status", "created_at"], pay_rows)
    emit(out, "shipments (delivered orders only)", "shipments",
         ["order_id", "carrier_id", "tracking_number", "shipped_at", "delivered_at"], ship_rows)

    # carts: users 1..10, deterministic active variants
    cart_rows, ci_rows = [], []
    for i in range(1, 11):
        token = uuid.uuid5(uuid.NAMESPACE_URL, f"db-samples-ecommerce-cart-{i}")
        cart_rows.append([str(i), str(i), q(str(token)), q("active")])
        for k in range(1 + (i % 3)):
            variant = active_variants[(i * 7 + k * 11) % len(active_variants)]
            ci_rows.append([str(i), str(variant), str((i + k) % 3 + 1)])
    emit(out, "carts (synthesized; Northwind has no cart concept)", "carts",
         ["cart_id", "user_id", "session_token", "status"], cart_rows)
    emit(out, "cart_items", "cart_items", ["cart_id", "variant_id", "qty"], ci_rows)

    # splice between markers
    ec = ECOMMERCE_SQL.read_text(encoding="utf-8")
    begin = ec.index(SEED_BEGIN) + len(SEED_BEGIN)
    end = ec.index(SEED_END)
    seed = "\n-- (generated by scripts/generate_ecommerce_seed.py - do not edit by hand)\n" \
           + "\n".join(out) + "\n"
    ECOMMERCE_SQL.write_text(ec[:begin] + seed + ec[end:], encoding="utf-8")
    print(f"OK: wrote {len(out)} seed lines "
          f"({len(user_rows)} users, {len(ord_rows)} orders, {len(item_rows)} order items)")


if __name__ == "__main__":
    main()
