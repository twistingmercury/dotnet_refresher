-- Deterministic fixtures: three orders with one, two, and three line items.
-- Reruns preserve existing rows; use a fresh container/data volume for pristine fixtures.
BEGIN;

INSERT INTO orders (order_id, customer_name, created_date, updated_date)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'Ada Lovelace', '2026-01-01 00:00:00+00', '2026-01-01 00:00:00+00'),
    ('00000000-0000-0000-0000-000000000002', 'Grace Hopper', '2026-01-01 00:00:00+00', '2026-01-01 00:00:00+00'),
    ('00000000-0000-0000-0000-000000000003', 'Alan Turing', '2026-01-01 00:00:00+00', '2026-01-01 00:00:00+00')
ON CONFLICT (order_id) DO NOTHING;

INSERT INTO order_details (order_id, line_number, product_name, qty, created_date, updated_date)
VALUES
    ('00000000-0000-0000-0000-000000000001', 1, 'Notebook', 2, '2026-01-01 00:00:00+00', '2026-01-01 00:00:00+00'),
    ('00000000-0000-0000-0000-000000000002', 1, 'Keyboard', 1, '2026-01-01 00:00:00+00', '2026-01-01 00:00:00+00'),
    ('00000000-0000-0000-0000-000000000002', 2, 'Mouse', 2, '2026-01-01 00:00:00+00', '2026-01-01 00:00:00+00'),
    ('00000000-0000-0000-0000-000000000003', 1, 'Monitor', 1, '2026-01-01 00:00:00+00', '2026-01-01 00:00:00+00'),
    ('00000000-0000-0000-0000-000000000003', 2, 'USB Cable', 3, '2026-01-01 00:00:00+00', '2026-01-01 00:00:00+00'),
    ('00000000-0000-0000-0000-000000000003', 3, 'Desk Lamp', 2, '2026-01-01 00:00:00+00', '2026-01-01 00:00:00+00')
ON CONFLICT (order_id, line_number) DO NOTHING;

COMMIT;
