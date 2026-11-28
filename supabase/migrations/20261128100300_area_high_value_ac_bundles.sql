insert into public.area_ac_packages(package_key,name,amount_ngn,base_ac,bonus_ac,sort_order,active)
values
 ('don','Don',10000,500000,35000,7,true),
 ('big_don','Big Don',15000,750000,56250,8,true),
 ('billionaire','Billionaire Pack',25000,1250000,100000,9,true),
 ('tycoon','Tycoon',50000,2500000,225000,10,true)
on conflict(package_key) do update
set name=excluded.name,amount_ngn=excluded.amount_ngn,base_ac=excluded.base_ac,bonus_ac=excluded.bonus_ac,sort_order=excluded.sort_order,active=excluded.active;