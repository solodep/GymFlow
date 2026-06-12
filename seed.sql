-- =====================================================================
--  GymFlow — тестовые данные (seed)
--  Даты заданы ОТНОСИТЕЛЬНО текущей даты (CURRENT_DATE), чтобы отчётные
--  запросы (за прошлый месяц / эту неделю / по месяцам) всегда возвращали
--  осмысленный результат, когда бы ты их ни запускал.
--  Запуск:  psql -U postgres -d gymflow -f seed.sql   (после schema.sql)
-- =====================================================================

-- ---------- Студии ----------
INSERT INTO club (club_id, name, city, address, phone, opens_at, closes_at) VALUES
 (1, 'GymFlow Центр', 'Москва', 'ул. Тверская, 10',     '+74950000001', TIME '07:00', TIME '23:00'),
 (2, 'GymFlow Север', 'Москва', 'ул. Лесная, 5',        '+74950000002', TIME '08:00', TIME '22:00'),
 (3, 'GymFlow Юг',    'Москва', 'Варшавское ш., 120',   '+74950000003', TIME '07:00', TIME '23:00');

-- ---------- Специализации ----------
INSERT INTO specialization (specialization_id, name) VALUES
 (1, 'Йога'), (2, 'Силовые'), (3, 'Бокс'), (4, 'Пилатес'), (5, 'Кроссфит');

-- ---------- Тренеры ----------
INSERT INTO trainer (trainer_id, full_name, phone, hired_at) VALUES
 (1, 'Анна Котова',      '+79010000001', DATE '2022-03-01'),
 (2, 'Иван Петров',      '+79010000002', DATE '2021-06-15'),
 (3, 'Сергей Лебедев',   '+79010000003', DATE '2023-01-10'),
 (4, 'Мария Орлова',     '+79010000004', DATE '2020-09-01'),
 (5, 'Дмитрий Соколов',  '+79010000005', DATE '2024-02-20');

-- ---------- M:N тренер–специализация (одна сторона MVD) ----------
INSERT INTO trainer_specialization (trainer_id, specialization_id) VALUES
 (1,1),(1,4),            -- Анна: Йога, Пилатес
 (2,2),(2,5),            -- Иван: Силовые, Кроссфит
 (3,3),                  -- Сергей: Бокс
 (4,1),(4,2),(4,4),      -- Мария: Йога, Силовые, Пилатес
 (5,2),(5,5);            -- Дмитрий: Силовые, Кроссфит

-- ---------- M:N тренер–студия (вторая, независимая сторона MVD) ----------
INSERT INTO trainer_club (trainer_id, club_id) VALUES
 (1,1),(1,2),
 (2,1),(2,3),
 (3,1),
 (4,2),(4,3),
 (5,1),(5,2),(5,3);

-- ---------- Типы занятий ----------
INSERT INTO class_type (class_type_id, name, default_duration_min, specialization_id) VALUES
 (1, 'Хатха-йога',        60, 1),
 (2, 'Силовая тренировка',55, 2),
 (3, 'Бокс-старт',        60, 3),
 (4, 'Пилатес-мат',       50, 4),
 (5, 'Кроссфит WOD',      45, 5);

-- ---------- Тарифные планы ----------
INSERT INTO membership_plan (plan_id, name, duration_days, price, class_limit, is_active) VALUES
 (1, 'Месяц',       30,  3000.00, NULL, TRUE),
 (2, 'Три месяца',  90,  8000.00, NULL, TRUE),
 (3, 'Год',        365, 28000.00, NULL, TRUE),
 (4, 'Студент-8',   30,  2000.00,    8, TRUE);

-- ---------- Клиенты ----------
INSERT INTO member (member_id, full_name, phone, email, birth_date, registered_at) VALUES
 (1,  'Олег Смирнов',      '+79110000001', 'oleg@mail.ru',    DATE '1995-04-12', CURRENT_DATE - 110),
 (2,  'Елена Кузнецова',   '+79110000002', 'elena@mail.ru',   DATE '1998-07-03', CURRENT_DATE - 12),
 (3,  'Павел Морозов',     '+79110000003', 'pavel@mail.ru',   DATE '1990-01-25', CURRENT_DATE - 45),
 (4,  'Наталья Волкова',   '+79110000004', 'natalia@mail.ru', DATE '2001-11-30', CURRENT_DATE - 18),
 (5,  'Артём Зайцев',      '+79110000005', 'artem@mail.ru',   DATE '1993-06-08', CURRENT_DATE - 60),
 (6,  'Юлия Соловьёва',    '+79110000006', 'yulia@mail.ru',   DATE '1999-02-14', CURRENT_DATE - 8),
 (7,  'Роман Попов',       '+79110000007', 'roman@mail.ru',   DATE '1988-09-19', CURRENT_DATE - 210),
 (8,  'Ксения Новикова',   '+79110000008', 'ksenia@mail.ru',  DATE '2000-03-22', CURRENT_DATE - 100),
 (9,  'Андрей Васильев',   '+79110000009', 'andrey@mail.ru',  DATE '1996-12-01', CURRENT_DATE - 3),
 (10, 'Татьяна Макарова',  '+79110000010', 'tatiana@mail.ru', DATE '1994-05-17', CURRENT_DATE - 22),
 (11, 'Игорь Фёдоров',     '+79110000011', 'igor@mail.ru',    DATE '1997-08-09', CURRENT_DATE - 30),
 (12, 'Светлана Алексеева','+79110000012', 'sveta@mail.ru',   DATE '1992-10-28', CURRENT_DATE - 5);

-- ---------- Абонементы (member_id = membership_id для простоты) ----------
INSERT INTO membership (membership_id, member_id, plan_id, start_date, end_date, status) VALUES
 (1,  1, 3, CURRENT_DATE - 100, CURRENT_DATE + 265, 'active'),
 (2,  2, 1, CURRENT_DATE - 10,  CURRENT_DATE + 20,  'active'),
 (3,  3, 2, CURRENT_DATE - 40,  CURRENT_DATE + 50,  'active'),
 (4,  4, 4, CURRENT_DATE - 15,  CURRENT_DATE + 15,  'active'),
 (5,  5, 1, CURRENT_DATE - 40,  CURRENT_DATE - 10,  'expired'),
 (6,  6, 1, CURRENT_DATE - 5,   CURRENT_DATE + 25,  'frozen'),
 (7,  7, 3, CURRENT_DATE - 200, CURRENT_DATE + 165, 'active'),
 (8,  8, 2, CURRENT_DATE - 95,  CURRENT_DATE - 5,   'expired'),
 (9,  9, 1, CURRENT_DATE - 2,   CURRENT_DATE + 28,  'active'),
 (10, 10,4, CURRENT_DATE - 20,  CURRENT_DATE + 10,  'active'),
 (11, 11,1, CURRENT_DATE - 10,  CURRENT_DATE + 20,  'active'),
 (12, 12,4, CURRENT_DATE - 7,   CURRENT_DATE + 23,  'active');
-- Клиенты 11 и 12 оформили абонемент, но ни разу не были на занятии
-- (только неявки/отмены/будущая бронь) — попадают в отчёт Q9 «платит, но не ходит».

-- ---------- Занятия ----------
-- Блок А: прошлый месяц (для отчёта «топ по заполняемости за прошлый месяц»)
INSERT INTO class_session (session_id, class_type_id, club_id, trainer_id, start_at, duration_min, capacity, status) VALUES
 (1, 1, 1, 1, date_trunc('month', CURRENT_DATE) - INTERVAL '11 days' + INTERVAL '18 hours', 60,  3, 'completed'),
 (2, 3, 1, 3, date_trunc('month', CURRENT_DATE) - INTERVAL '10 days' + INTERVAL '19 hours', 60,  8, 'completed'),
 (3, 5, 1, 2, date_trunc('month', CURRENT_DATE) - INTERVAL '9 days'  + INTERVAL '18 hours', 45,  5, 'completed'),
 (4, 4, 2, 4, date_trunc('month', CURRENT_DATE) - INTERVAL '8 days'  + INTERVAL '10 hours', 50,  6, 'completed'),
 (5, 2, 3, 5, date_trunc('month', CURRENT_DATE) - INTERVAL '7 days'  + INTERVAL '20 hours', 55, 10, 'completed'),
-- Блок Б: текущая неделя (для отчёта «загрузка тренеров за неделю»)
 (6, 1, 2, 1, date_trunc('week', CURRENT_DATE)  + INTERVAL '1 day 18 hours',  60,  4, 'completed'),
 (7, 5, 1, 5, date_trunc('week', CURRENT_DATE)  + INTERVAL '2 days 19 hours', 45,  8, 'scheduled'),
 (8, 3, 1, 3, date_trunc('week', CURRENT_DATE)  + INTERVAL '3 days 20 hours', 60,  8, 'scheduled'),
-- Блок В: будущие занятия (для брони и листа ожидания / транзакций)
 (9, 4, 3, 4, date_trunc('day', CURRENT_DATE)   + INTERVAL '3 days 18 hours', 50,  2, 'scheduled'),
 (10,2, 1, 2, date_trunc('day', CURRENT_DATE)   + INTERVAL '4 days 19 hours', 55, 10, 'scheduled'),
 (11,5, 2, 5, date_trunc('day', CURRENT_DATE)   + INTERVAL '5 days 18 hours', 45,  6, 'scheduled'),
 (12,1, 2, 1, date_trunc('day', CURRENT_DATE)   + INTERVAL '6 days 9 hours',  60,  4, 'scheduled');

-- ---------- Брони ----------
INSERT INTO booking (session_id, member_id, status) VALUES
 -- s1 (cap 3) -> 100% заполняемость
 (1, 1, 'attended'), (1, 2, 'attended'), (1, 3, 'attended'),
 -- s2 (cap 8) -> 6/8
 (2, 1, 'attended'), (2, 2, 'attended'), (2, 4, 'attended'),
 (2, 5, 'attended'), (2, 6, 'attended'), (2, 7, 'attended'),
 (2, 11,'no_show'),
 -- s3 (cap 5) -> 3/5
 (3, 3, 'attended'), (3, 8, 'attended'), (3, 9, 'attended'),
 -- s4 (cap 6) -> 2/6
 (4, 2, 'attended'), (4, 4, 'attended'),
 -- s5 (cap 10) -> 3/10
 (5, 5, 'attended'), (5, 7, 'attended'), (5, 10,'attended'),
 -- текущая неделя
 (6, 4, 'confirmed'), (6, 6, 'confirmed'),
 (7, 5, 'confirmed'), (7, 9, 'confirmed'), (7, 10,'confirmed'), (7, 11,'cancelled'),
 (8, 7, 'confirmed'), (8, 12,'confirmed'),
 -- будущее: s9 (cap 2) заполнено + лист ожидания
 (9, 1, 'confirmed'), (9, 2, 'confirmed'), (9, 3, 'waitlisted'),
 (10,4, 'confirmed'),
 (11,5, 'confirmed'),
 (12,6, 'confirmed');

-- ---------- Оплаты (разнесены по месяцам для отчёта о выручке) ----------
INSERT INTO payment (member_id, membership_id, amount, paid_at, method) VALUES
 (7, 7, 28000.00, date_trunc('month', CURRENT_DATE) - INTERVAL '4 months' + INTERVAL '3 days 12 hours', 'card'),
 (8, 8,  8000.00, date_trunc('month', CURRENT_DATE) - INTERVAL '3 months' + INTERVAL '5 days 12 hours', 'online'),
 (3, 3,  8000.00, date_trunc('month', CURRENT_DATE) - INTERVAL '3 months' + INTERVAL '12 days 12 hours','card'),
 (5, 5,  3000.00, date_trunc('month', CURRENT_DATE) - INTERVAL '2 months' + INTERVAL '2 days 12 hours', 'cash'),
 (1, 1, 28000.00, date_trunc('month', CURRENT_DATE) - INTERVAL '2 months' + INTERVAL '9 days 12 hours', 'card'),
 (2, 2,  3000.00, date_trunc('month', CURRENT_DATE) - INTERVAL '1 months' + INTERVAL '4 days 12 hours', 'card'),
 (4, 4,  2000.00, date_trunc('month', CURRENT_DATE) - INTERVAL '1 months' + INTERVAL '6 days 12 hours', 'online'),
 (9, 9,  3000.00, date_trunc('month', CURRENT_DATE) - INTERVAL '1 months' + INTERVAL '20 days 12 hours','card'),
 (10, NULL, 700.00, date_trunc('month', CURRENT_DATE) - INTERVAL '1 months' + INTERVAL '22 days 12 hours','cash'),
 (6, 6,  3000.00, date_trunc('month', CURRENT_DATE) + INTERVAL '2 days 12 hours', 'card'),
 (10,10, 2000.00, date_trunc('month', CURRENT_DATE) + INTERVAL '4 days 12 hours', 'online'),
 (11, NULL, 700.00, date_trunc('month', CURRENT_DATE) + INTERVAL '6 days 12 hours', 'cash');

-- ---------- Отзывы ----------
INSERT INTO review (member_id, session_id, rating, comment) VALUES
 (1, 1, 5, 'Отличная йога, спокойный темп'),
 (2, 1, 4, 'Хорошо, но зал прохладный'),
 (3, 3, 5, 'Жёсткий кроссфит, как люблю'),
 (4, 4, 3, 'Среднее занятие'),
 (7, 5, 4, 'Сильная силовая, приду ещё');

-- ---------- Синхронизация последовательностей SERIAL ----------
SELECT setval(pg_get_serial_sequence('club','club_id'),                     (SELECT MAX(club_id)            FROM club));
SELECT setval(pg_get_serial_sequence('member','member_id'),                 (SELECT MAX(member_id)         FROM member));
SELECT setval(pg_get_serial_sequence('membership_plan','plan_id'),          (SELECT MAX(plan_id)          FROM membership_plan));
SELECT setval(pg_get_serial_sequence('membership','membership_id'),         (SELECT MAX(membership_id)    FROM membership));
SELECT setval(pg_get_serial_sequence('trainer','trainer_id'),               (SELECT MAX(trainer_id)       FROM trainer));
SELECT setval(pg_get_serial_sequence('specialization','specialization_id'), (SELECT MAX(specialization_id) FROM specialization));
SELECT setval(pg_get_serial_sequence('class_type','class_type_id'),         (SELECT MAX(class_type_id)    FROM class_type));
SELECT setval(pg_get_serial_sequence('class_session','session_id'),         (SELECT MAX(session_id)       FROM class_session));
SELECT setval(pg_get_serial_sequence('booking','booking_id'),               (SELECT MAX(booking_id)       FROM booking));
SELECT setval(pg_get_serial_sequence('payment','payment_id'),               (SELECT MAX(payment_id)       FROM payment));
SELECT setval(pg_get_serial_sequence('review','review_id'),                 (SELECT MAX(review_id)        FROM review));
