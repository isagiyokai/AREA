-- Reduce promotional AC bonuses to a sustainable, fee-aware curve.
update public.area_ac_packages set bonus_ac=case package_key when 'street' then 250 when 'regular' then 1500 when 'big_man' then 5000 when 'odogwu' then 15000 else 0 end
where package_key in('pocket','small','street','regular','big_man','odogwu');
