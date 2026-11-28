-- Index payment-order foreign keys and limit the owner-profile probe to signed-in users.
create index if not exists area_payment_orders_package_key_idx on private.area_payment_orders(package_key);
revoke execute on function public.is_area_admin_profile(uuid) from anon;
grant execute on function public.is_area_admin_profile(uuid) to authenticated;
