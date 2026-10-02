insert into public.stations (name_ar, sort_order) values
  ('لعوايد', 1), ('المثلث', 2), ('ابو الحسن', 3), ('اول السور', 4), ('شارع الترعه', 5),
  ('قصر الشوق', 6), ('براديس', 7), ('البان فرحه', 8), ('شارع ناصر', 9), ('الكابنون', 10),
  ('الاستقامه', 11), ('كليه طب', 12), ('الإسعاف', 13), ('الدمياطي', 14), ('الجامع الكبير', 15),
  ('شارع عثمان', 16), ('شبراوى', 17), ('اول نافع', 18), ('شيخ البلد', 19), ('المجمع الطبي', 20),
  ('نبى الله', 21), ('لفظ الجلاله', 22), ('الحريه', 23), ('النهضه', 24), ('ساندبيتش', 25),
  ('مارينا وادي دجله', 26), ('دولفين', 27), ('جولدن كوست', 28), ('مونت الجلاله', 29)
on conflict do nothing;

insert into public.departure_times (time, label, sort_order) values ('09:00:00', '09:00', 1) on conflict (time) do nothing;

insert into public.admin_settings (key, value, description) values
  ('default_trip_capacity', '40', 'Default capacity for a newly created trip.'),
  ('cancellation_cutoff_hours', '4', 'Hours before departure when student cancellation closes.'),
  ('booking_horizon_days', '30', 'How far in the future a student may book.'),
  ('registration_requires_registry', 'false', 'When true, only student IDs in student_registry may register.')
on conflict (key) do update set value = excluded.value, description = excluded.description;
