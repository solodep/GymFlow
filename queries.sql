-- =====================================================================
--  GymFlow — Раздел 1.10 SQL DML
--  Для каждого запроса: какое ФТ реализует / кто пользователь / зачем важен.
-- =====================================================================

-- =========================  ПРОСТЫЕ (CRUD)  ==========================

-- Q1. Регистрация нового клиента.
-- ФТ: добавление клиента | Пользователь: администратор стойки | Зачем: завести карточку при первом визите.
INSERT INTO member (full_name, phone, email, birth_date)
VALUES ('Новый Клиент', '+79110009999', 'new@mail.ru', DATE '2000-01-01');

-- Q2. Расписание студии на ближайшую неделю.
-- ФТ: просмотр расписания | Пользователь: клиент / администратор | Зачем: выбрать занятие для записи.
SELECT s.start_at, ct.name AS class_name, t.full_name AS trainer, s.capacity
FROM class_session s
JOIN class_type ct ON ct.class_type_id = s.class_type_id
JOIN trainer    t  ON t.trainer_id     = s.trainer_id
WHERE s.club_id = 1
  AND s.start_at >= CURRENT_DATE
  AND s.start_at <  CURRENT_DATE + INTERVAL '7 days'
ORDER BY s.start_at;

-- Q3. Заморозка абонемента.
-- ФТ: изменение статуса абонемента | Пользователь: клиент (через администратора) | Зачем: пауза на время отъезда.
UPDATE membership SET status = 'frozen' WHERE membership_id = 2;

-- Q4. Отмена брони.
-- ФТ: отмена записи | Пользователь: клиент | Зачем: освободить место в зале.
UPDATE booking SET status = 'cancelled' WHERE booking_id = 19;

-- Q5. Действующие абонементы клиента.
-- ФТ: просмотр своих абонементов | Пользователь: клиент в личном кабинете | Зачем: понять, до какой даты есть доступ.
SELECT mp.name, m.start_date, m.end_date, m.status
FROM membership m
JOIN membership_plan mp ON mp.plan_id = m.plan_id
WHERE m.member_id = 1 AND m.status = 'active';

-- Q6. Тренеры студии и их специализации (показывает M:N-таблицы из 4NF).
-- ФТ: каталог тренеров студии | Пользователь: клиент | Зачем: выбрать тренера по направлению.
SELECT t.full_name,
       string_agg(sp.name, ', ' ORDER BY sp.name) AS specializations
FROM trainer t
JOIN trainer_club           tc ON tc.trainer_id = t.trainer_id
LEFT JOIN trainer_specialization ts ON ts.trainer_id = t.trainer_id
LEFT JOIN specialization    sp ON sp.specialization_id = ts.specialization_id
WHERE tc.club_id = 1
GROUP BY t.trainer_id, t.full_name
ORDER BY t.full_name;


-- =========================  СЛОЖНЫЕ  =================================

-- Q7. Топ-5 занятий по заполняемости за ПРОШЛЫЙ месяц.
-- JOIN + LEFT JOIN + GROUP BY + агрегат с FILTER + оконная RANK().
-- ФТ: аналитика загрузки | Пользователь: управляющий сетью | Зачем: понять, какие занятия востребованы.
SELECT ct.name AS class_name, c.name AS club, s.start_at,
       COUNT(b.booking_id) FILTER (WHERE b.status IN ('confirmed','attended')) AS booked,
       s.capacity,
       ROUND(100.0 * COUNT(b.booking_id) FILTER (WHERE b.status IN ('confirmed','attended'))
             / s.capacity, 1) AS fill_pct,
       RANK() OVER (ORDER BY COUNT(b.booking_id)
             FILTER (WHERE b.status IN ('confirmed','attended'))::numeric / s.capacity DESC) AS rnk
FROM class_session s
JOIN class_type ct ON ct.class_type_id = s.class_type_id
JOIN club       c  ON c.club_id        = s.club_id
LEFT JOIN booking b ON b.session_id     = s.session_id
WHERE s.start_at >= date_trunc('month', CURRENT_DATE) - INTERVAL '1 month'
  AND s.start_at <  date_trunc('month', CURRENT_DATE)
GROUP BY ct.name, c.name, s.start_at, s.capacity
ORDER BY fill_pct DESC
LIMIT 5;

-- Q8. Помесячная выручка и рост к предыдущему месяцу.
-- Подзапрос + GROUP BY + оконные LAG() и нарастающий SUM() OVER.
-- ФТ: финансовая отчётность | Пользователь: бухгалтер / управляющий | Зачем: видеть динамику доходов.
SELECT month, revenue,
       LAG(revenue) OVER (ORDER BY month) AS prev_revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 1) AS growth_pct,
       SUM(revenue) OVER (ORDER BY month) AS running_total
FROM (
  SELECT date_trunc('month', paid_at)::date AS month, SUM(amount) AS revenue
  FROM payment
  GROUP BY 1
) m
ORDER BY month;

-- Q9. Клиенты, которые бронировали занятия, но ни разу не посетили.
-- Коррелированные подзапросы EXISTS / NOT EXISTS (анти-join).
-- ФТ: выявление "уходящих" клиентов | Пользователь: отдел удержания | Зачем: основа для рассылки/обзвона.
SELECT m.member_id, m.full_name
FROM member m
WHERE EXISTS     (SELECT 1 FROM booking b WHERE b.member_id = m.member_id)
  AND NOT EXISTS (SELECT 1 FROM booking b WHERE b.member_id = m.member_id
                                            AND b.status = 'attended');

-- Q10. Загрузка тренеров за текущую неделю (занятия, часы, уникальные клиенты).
-- Две CTE + JOIN. ВАЖНО: занятия/часы и клиентов считаем РАЗДЕЛЬНО, иначе
-- JOIN с booking «размножает» строки и SUM(duration_min) задваивается (fan-out).
-- ФТ: контроль нагрузки персонала | Пользователь: управляющий студией | Зачем: балансировать расписание.
WITH wk AS (
  SELECT date_trunc('week', CURRENT_DATE) AS w_start,
         date_trunc('week', CURRENT_DATE) + INTERVAL '1 week' AS w_end
),
sess AS (   -- метрики по занятиям (без брони — нет задвоения)
  SELECT s.trainer_id, COUNT(*) AS sessions, SUM(s.duration_min) AS minutes
  FROM class_session s, wk
  WHERE s.start_at >= wk.w_start AND s.start_at < wk.w_end
  GROUP BY s.trainer_id
),
cli AS (    -- уникальные клиенты по бронированиям
  SELECT s.trainer_id, COUNT(DISTINCT b.member_id) AS unique_clients
  FROM class_session s
  JOIN booking b ON b.session_id = s.session_id AND b.status IN ('confirmed','attended')
  , wk
  WHERE s.start_at >= wk.w_start AND s.start_at < wk.w_end
  GROUP BY s.trainer_id
)
SELECT t.trainer_id, t.full_name,
       sess.sessions,
       ROUND(sess.minutes / 60.0, 2) AS hours,
       COALESCE(cli.unique_clients, 0) AS unique_clients
FROM trainer t
JOIN sess      ON sess.trainer_id = t.trainer_id
LEFT JOIN cli  ON cli.trainer_id  = t.trainer_id
ORDER BY hours DESC;
