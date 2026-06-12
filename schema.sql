-- =====================================================================
--  GymFlow — сеть фитнес-студий
--  Раздел 1.9 — SQL DDL (PostgreSQL)
--  Запуск:  psql -U postgres -d gymflow -f schema.sql
-- =====================================================================

-- Чистый пересоздаваемый скрипт: дропаем в обратном порядке зависимостей
DROP TABLE IF EXISTS review                CASCADE;
DROP TABLE IF EXISTS payment               CASCADE;
DROP TABLE IF EXISTS booking               CASCADE;
DROP TABLE IF EXISTS class_session         CASCADE;
DROP TABLE IF EXISTS class_type            CASCADE;
DROP TABLE IF EXISTS trainer_club          CASCADE;
DROP TABLE IF EXISTS trainer_specialization CASCADE;
DROP TABLE IF EXISTS specialization        CASCADE;
DROP TABLE IF EXISTS trainer               CASCADE;
DROP TABLE IF EXISTS membership            CASCADE;
DROP TABLE IF EXISTS membership_plan       CASCADE;
DROP TABLE IF EXISTS member                CASCADE;
DROP TABLE IF EXISTS club                  CASCADE;

-- ---------------------------------------------------------------------
-- Справочники / основные сущности
-- ---------------------------------------------------------------------
CREATE TABLE club (
  club_id   SERIAL PRIMARY KEY,
  name      VARCHAR(100) NOT NULL,
  city      VARCHAR(60)  NOT NULL,
  address   VARCHAR(200) NOT NULL,
  phone     VARCHAR(20),
  opens_at  TIME NOT NULL,
  closes_at TIME NOT NULL,
  CONSTRAINT chk_club_hours CHECK (closes_at > opens_at)
);

CREATE TABLE member (
  member_id     SERIAL PRIMARY KEY,
  full_name     VARCHAR(120) NOT NULL,
  phone         VARCHAR(20)  NOT NULL UNIQUE,
  email         VARCHAR(120) UNIQUE,
  birth_date    DATE,
  registered_at TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE membership_plan (
  plan_id       SERIAL PRIMARY KEY,
  name          VARCHAR(80) NOT NULL,
  duration_days INT NOT NULL CHECK (duration_days > 0),
  price         NUMERIC(10,2) NOT NULL CHECK (price >= 0),
  class_limit   INT CHECK (class_limit IS NULL OR class_limit > 0),  -- NULL = безлимит
  is_active     BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE membership (
  membership_id SERIAL PRIMARY KEY,
  member_id     INT NOT NULL REFERENCES member(member_id),
  plan_id       INT NOT NULL REFERENCES membership_plan(plan_id),
  start_date    DATE NOT NULL,
  end_date      DATE NOT NULL,
  status        VARCHAR(10) NOT NULL DEFAULT 'active'
                CHECK (status IN ('active','frozen','expired','cancelled')),
  CONSTRAINT chk_membership_dates CHECK (end_date >= start_date)
);

CREATE TABLE trainer (
  trainer_id SERIAL PRIMARY KEY,
  full_name  VARCHAR(120) NOT NULL,
  phone      VARCHAR(20),
  hired_at   DATE NOT NULL
);

CREATE TABLE specialization (
  specialization_id SERIAL PRIMARY KEY,
  name VARCHAR(60) NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------
-- M:N связи тренера (результат декомпозиции MVD в 4NF):
--   trainer_id ->> specialization_id   |   trainer_id ->> club_id
-- ---------------------------------------------------------------------
CREATE TABLE trainer_specialization (
  trainer_id        INT NOT NULL REFERENCES trainer(trainer_id),
  specialization_id INT NOT NULL REFERENCES specialization(specialization_id),
  PRIMARY KEY (trainer_id, specialization_id)
);

CREATE TABLE trainer_club (
  trainer_id INT NOT NULL REFERENCES trainer(trainer_id),
  club_id    INT NOT NULL REFERENCES club(club_id),
  PRIMARY KEY (trainer_id, club_id)
);

-- ---------------------------------------------------------------------
-- Занятия и расписание
-- ---------------------------------------------------------------------
CREATE TABLE class_type (
  class_type_id        SERIAL PRIMARY KEY,
  name                 VARCHAR(80) NOT NULL,
  default_duration_min INT NOT NULL CHECK (default_duration_min > 0),
  specialization_id    INT REFERENCES specialization(specialization_id)
);

CREATE TABLE class_session (
  session_id    SERIAL PRIMARY KEY,
  class_type_id INT NOT NULL REFERENCES class_type(class_type_id),
  club_id       INT NOT NULL REFERENCES club(club_id),
  trainer_id    INT NOT NULL REFERENCES trainer(trainer_id),
  start_at      TIMESTAMP NOT NULL,
  duration_min  INT NOT NULL CHECK (duration_min > 0),
  capacity      INT NOT NULL CHECK (capacity > 0),
  status        VARCHAR(10) NOT NULL DEFAULT 'scheduled'
                CHECK (status IN ('scheduled','completed','cancelled')),
  -- тренер физически не может вести два занятия одновременно
  CONSTRAINT uq_trainer_slot UNIQUE (trainer_id, start_at)
);

CREATE TABLE booking (
  booking_id SERIAL PRIMARY KEY,
  session_id INT NOT NULL REFERENCES class_session(session_id),
  member_id  INT NOT NULL REFERENCES member(member_id),
  status     VARCHAR(10) NOT NULL DEFAULT 'confirmed'
             CHECK (status IN ('confirmed','waitlisted','cancelled','attended','no_show')),
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  -- клиент не может записаться на одно и то же занятие дважды
  CONSTRAINT uq_booking UNIQUE (session_id, member_id)
);

CREATE TABLE payment (
  payment_id    SERIAL PRIMARY KEY,
  member_id     INT NOT NULL REFERENCES member(member_id),
  membership_id INT REFERENCES membership(membership_id),  -- NULL = разовая оплата
  amount        NUMERIC(10,2) NOT NULL CHECK (amount > 0),
  paid_at       TIMESTAMP NOT NULL DEFAULT now(),
  method        VARCHAR(10) NOT NULL CHECK (method IN ('card','cash','online'))
);

CREATE TABLE review (
  review_id  SERIAL PRIMARY KEY,
  member_id  INT NOT NULL REFERENCES member(member_id),
  session_id INT NOT NULL REFERENCES class_session(session_id),
  rating     INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment    TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT uq_review UNIQUE (member_id, session_id)
);

-- ---------------------------------------------------------------------
-- Индексы под типовые отчёты (раздел НФТ — производительность)
-- ---------------------------------------------------------------------
CREATE INDEX idx_session_club_time ON class_session(club_id, start_at);
CREATE INDEX idx_session_trainer   ON class_session(trainer_id);
CREATE INDEX idx_booking_session   ON booking(session_id);
CREATE INDEX idx_booking_member    ON booking(member_id);
CREATE INDEX idx_payment_paid_at   ON payment(paid_at);
CREATE INDEX idx_membership_member ON membership(member_id);
