-- =====================================================================
--  GymFlow — дополнительные ограничения через триггеры (опционально)
--  Применять ПОСЛЕ schema.sql и seed.sql:
--      psql -d gymflow -f triggers.sql
--  schema.sql дропает таблицы CASCADE -> триггеры удаляются вместе с ними,
--  поэтому цикл сброса всегда: schema.sql -> seed.sql -> triggers.sql.
--
--  Почему триггеры, а не CHECK: оба правила ссылаются на ДРУГИЕ строки/таблицы,
--  что обычный CHECK выразить не может.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Правило 1. Новую активную бронь (confirmed/waitlisted) можно создать,
-- только если у клиента есть АКТИВНЫЙ абонемент, покрывающий дату занятия.
-- Статусы attended/no_show/cancelled — исторические, их не проверяем.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_booking_active_membership() RETURNS trigger AS $$
DECLARE
  v_date date;
BEGIN
  IF NEW.status NOT IN ('confirmed','waitlisted') THEN
    RETURN NEW;
  END IF;

  SELECT start_at::date INTO v_date
  FROM class_session WHERE session_id = NEW.session_id;

  IF NOT EXISTS (
    SELECT 1 FROM membership m
    WHERE m.member_id = NEW.member_id
      AND m.status = 'active'
      AND v_date BETWEEN m.start_date AND m.end_date
  ) THEN
    RAISE EXCEPTION
      'Бронь отклонена: у клиента % нет активного абонемента на дату занятия %.',
      NEW.member_id, v_date;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS booking_active_membership ON booking;
CREATE TRIGGER booking_active_membership
  BEFORE INSERT ON booking
  FOR EACH ROW EXECUTE FUNCTION trg_booking_active_membership();

-- ---------------------------------------------------------------------
-- Правило 2. Тренер ведёт занятие только в той студии, к которой
-- он прикреплён (есть запись в trainer_club).
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION trg_session_trainer_club() RETURNS trigger AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM trainer_club tc
    WHERE tc.trainer_id = NEW.trainer_id
      AND tc.club_id    = NEW.club_id
  ) THEN
    RAISE EXCEPTION
      'Занятие отклонено: тренер % не закреплён за студией %.',
      NEW.trainer_id, NEW.club_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS session_trainer_club ON class_session;
CREATE TRIGGER session_trainer_club
  BEFORE INSERT OR UPDATE ON class_session
  FOR EACH ROW EXECUTE FUNCTION trg_session_trainer_club();

-- Примечание: контроль вместимости занятия и лимита занятий по тарифу
-- (class_limit) реализован в транзакциях/приложении (см. transactions.sql),
-- а НЕ триггером — осознанное решение (раздел «Спорные проектные решения»).
