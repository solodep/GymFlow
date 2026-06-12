-- =====================================================================
--  GymFlow — Раздел 1.11 Транзакции
--  Демонстрационные значения (session_id / member_id) рассчитаны на данные
--  из seed.sql. На своих данных подставь актуальные id.
-- =====================================================================

-- ---------------------------------------------------------------------
-- T1. Бронирование с лимитом мест и листом ожидания.
--     Граница транзакции: проверка свободных мест + создание брони — одно целое.
-- ---------------------------------------------------------------------
BEGIN;
  -- Блокируем строку занятия: параллельная бронь этого же занятия будет ждать,
  -- пока мы не зафиксируем транзакцию. Это убирает гонку за последнее место.
  SELECT capacity FROM class_session WHERE session_id = 9 FOR UPDATE;

  INSERT INTO booking (session_id, member_id, status)
  VALUES (9, 7,
    CASE WHEN (SELECT count(*) FROM booking
               WHERE session_id = 9 AND status = 'confirmed')
              < (SELECT capacity FROM class_session WHERE session_id = 9)
         THEN 'confirmed'
         ELSE 'waitlisted' END);
COMMIT;
-- Без блокировки/транзакции: два клиента одновременно читают «свободно 1 место»
-- и оба получают confirmed -> зал перезаписан сверх вместимости.


-- ---------------------------------------------------------------------
-- T2. Покупка абонемента: оплата и активация — атомарно.
-- ---------------------------------------------------------------------
BEGIN;
  INSERT INTO membership (member_id, plan_id, start_date, end_date, status)
  VALUES (11, 1, CURRENT_DATE,
          CURRENT_DATE + (SELECT duration_days FROM membership_plan WHERE plan_id = 1),
          'active');

  INSERT INTO payment (member_id, membership_id, amount, method)
  VALUES (11,
          currval(pg_get_serial_sequence('membership','membership_id')),
          (SELECT price FROM membership_plan WHERE plan_id = 1),
          'card');
COMMIT;
-- Без транзакции: возможны состояния «деньги списаны, абонемент не создан»
-- или «абонемент активен, оплаты нет» — оба недопустимы.


-- ---------------------------------------------------------------------
-- T3. Отмена брони + продвижение первого из листа ожидания — атомарно.
-- ---------------------------------------------------------------------
BEGIN;
  UPDATE booking SET status = 'cancelled'
  WHERE session_id = 9 AND member_id = 1 AND status = 'confirmed';

  UPDATE booking SET status = 'confirmed'
  WHERE booking_id = (
    SELECT booking_id FROM booking
    WHERE session_id = 9 AND status = 'waitlisted'
    ORDER BY created_at
    LIMIT 1
    FOR UPDATE SKIP LOCKED   -- не даём двум параллельным отменам продвинуть одного и того же
  );
COMMIT;
-- Без атомарности: место освободилось, но из листа ожидания никого не подняли,
-- либо одного клиента продвинули сразу две параллельные отмены.
