# -*- coding: utf-8 -*-
"""
GymFlow — проверка логики схемы и запросов на встроенном SQLite.
Это НЕ замена PostgreSQL: основной целевой движок — Postgres (schema.sql/seed.sql/
queries.sql/transactions.sql). Скрипт нужен, чтобы быстро убедиться, что структура
целостна, ограничения срабатывают, а сложные запросы возвращают осмысленный результат.

Запуск:  py verify.py
"""
import sqlite3
from datetime import date, timedelta

# ---------- вычисляем относительные даты так же, как в seed.sql ----------
today = date.today()

def first_of_month(d):
    return d.replace(day=1)

def add_months(d, k):
    m = d.month - 1 + k
    y = d.year + m // 12
    return date(y, m % 12 + 1, 1)

def monday(d):
    return d - timedelta(days=d.weekday())

def ts(d, h=0, m=0):
    return f"{d.isoformat()} {h:02d}:{m:02d}:00"

fom = first_of_month(today)
mon = monday(today)

# ---------- схема (SQLite-диалект; даты как TEXT, BOOLEAN как INT) ----------
SCHEMA = """
CREATE TABLE club(club_id INTEGER PRIMARY KEY, name TEXT, city TEXT, address TEXT,
  phone TEXT, opens_at TEXT, closes_at TEXT, CHECK(closes_at>opens_at));
CREATE TABLE member(member_id INTEGER PRIMARY KEY, full_name TEXT, phone TEXT UNIQUE,
  email TEXT UNIQUE, birth_date TEXT, registered_at TEXT);
CREATE TABLE membership_plan(plan_id INTEGER PRIMARY KEY, name TEXT, duration_days INT,
  price NUMERIC, class_limit INT, is_active INT, CHECK(duration_days>0), CHECK(price>=0),
  CHECK(class_limit IS NULL OR class_limit>0));
CREATE TABLE membership(membership_id INTEGER PRIMARY KEY, member_id INT REFERENCES member,
  plan_id INT REFERENCES membership_plan, start_date TEXT, end_date TEXT,
  status TEXT CHECK(status IN('active','frozen','expired','cancelled')), CHECK(end_date>=start_date));
CREATE TABLE trainer(trainer_id INTEGER PRIMARY KEY, full_name TEXT, phone TEXT, hired_at TEXT);
CREATE TABLE specialization(specialization_id INTEGER PRIMARY KEY, name TEXT UNIQUE);
CREATE TABLE trainer_specialization(trainer_id INT REFERENCES trainer,
  specialization_id INT REFERENCES specialization, PRIMARY KEY(trainer_id,specialization_id));
CREATE TABLE trainer_club(trainer_id INT REFERENCES trainer, club_id INT REFERENCES club,
  PRIMARY KEY(trainer_id,club_id));
CREATE TABLE class_type(class_type_id INTEGER PRIMARY KEY, name TEXT, default_duration_min INT,
  specialization_id INT REFERENCES specialization, CHECK(default_duration_min>0));
CREATE TABLE class_session(session_id INTEGER PRIMARY KEY, class_type_id INT REFERENCES class_type,
  club_id INT REFERENCES club, trainer_id INT REFERENCES trainer, start_at TEXT, duration_min INT,
  capacity INT, status TEXT CHECK(status IN('scheduled','completed','cancelled')),
  CHECK(duration_min>0), CHECK(capacity>0), UNIQUE(trainer_id,start_at));
CREATE TABLE booking(booking_id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INT REFERENCES class_session,
  member_id INT REFERENCES member,
  status TEXT CHECK(status IN('confirmed','waitlisted','cancelled','attended','no_show')),
  created_at TEXT DEFAULT CURRENT_TIMESTAMP, UNIQUE(session_id,member_id));
CREATE TABLE payment(payment_id INTEGER PRIMARY KEY AUTOINCREMENT, member_id INT REFERENCES member,
  membership_id INT REFERENCES membership, amount NUMERIC, paid_at TEXT,
  method TEXT CHECK(method IN('card','cash','online')), CHECK(amount>0));
CREATE TABLE review(review_id INTEGER PRIMARY KEY AUTOINCREMENT, member_id INT REFERENCES member,
  session_id INT REFERENCES class_session, rating INT, comment TEXT, created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  CHECK(rating BETWEEN 1 AND 5), UNIQUE(member_id,session_id));
"""

def seed(cur):
    cur.executemany("INSERT INTO club VALUES(?,?,?,?,?,?,?)", [
        (1,'GymFlow Центр','Москва','ул. Тверская, 10','+74950000001','07:00','23:00'),
        (2,'GymFlow Север','Москва','ул. Лесная, 5','+74950000002','08:00','22:00'),
        (3,'GymFlow Юг','Москва','Варшавское ш., 120','+74950000003','07:00','23:00'),
    ])
    cur.executemany("INSERT INTO specialization VALUES(?,?)",
        [(1,'Йога'),(2,'Силовые'),(3,'Бокс'),(4,'Пилатес'),(5,'Кроссфит')])
    cur.executemany("INSERT INTO trainer VALUES(?,?,?,?)", [
        (1,'Анна Котова','+79010000001','2022-03-01'),(2,'Иван Петров','+79010000002','2021-06-15'),
        (3,'Сергей Лебедев','+79010000003','2023-01-10'),(4,'Мария Орлова','+79010000004','2020-09-01'),
        (5,'Дмитрий Соколов','+79010000005','2024-02-20')])
    cur.executemany("INSERT INTO trainer_specialization VALUES(?,?)",
        [(1,1),(1,4),(2,2),(2,5),(3,3),(4,1),(4,2),(4,4),(5,2),(5,5)])
    cur.executemany("INSERT INTO trainer_club VALUES(?,?)",
        [(1,1),(1,2),(2,1),(2,3),(3,1),(4,2),(4,3),(5,1),(5,2),(5,3)])
    cur.executemany("INSERT INTO class_type VALUES(?,?,?,?)",
        [(1,'Хатха-йога',60,1),(2,'Силовая тренировка',55,2),(3,'Бокс-старт',60,3),
         (4,'Пилатес-мат',50,4),(5,'Кроссфит WOD',45,5)])
    cur.executemany("INSERT INTO membership_plan VALUES(?,?,?,?,?,?)",
        [(1,'Месяц',30,3000,None,1),(2,'Три месяца',90,8000,None,1),
         (3,'Год',365,28000,None,1),(4,'Студент-8',30,2000,8,1)])
    members=[(i, n, p, e) for i,n,p,e in [
        (1,'Олег Смирнов','+79110000001','oleg@mail.ru'),(2,'Елена Кузнецова','+79110000002','elena@mail.ru'),
        (3,'Павел Морозов','+79110000003','pavel@mail.ru'),(4,'Наталья Волкова','+79110000004','natalia@mail.ru'),
        (5,'Артём Зайцев','+79110000005','artem@mail.ru'),(6,'Юлия Соловьёва','+79110000006','yulia@mail.ru'),
        (7,'Роман Попов','+79110000007','roman@mail.ru'),(8,'Ксения Новикова','+79110000008','ksenia@mail.ru'),
        (9,'Андрей Васильев','+79110000009','andrey@mail.ru'),(10,'Татьяна Макарова','+79110000010','tatiana@mail.ru'),
        (11,'Игорь Фёдоров','+79110000011','igor@mail.ru'),(12,'Светлана Алексеева','+79110000012','sveta@mail.ru')]]
    cur.executemany("INSERT INTO member(member_id,full_name,phone,email,birth_date,registered_at) VALUES(?,?,?,?,?,?)",
        [(i,n,p,e,'1995-01-01', ts(today-timedelta(days=30))) for (i,n,p,e) in members])
    cur.executemany("INSERT INTO membership VALUES(?,?,?,?,?,?)", [
        (1,1,3,ts(today-timedelta(days=100)),ts(today+timedelta(days=265)),'active'),
        (2,2,1,ts(today-timedelta(days=10)),ts(today+timedelta(days=20)),'active'),
        (3,3,2,ts(today-timedelta(days=40)),ts(today+timedelta(days=50)),'active'),
        (4,4,4,ts(today-timedelta(days=15)),ts(today+timedelta(days=15)),'active'),
        (5,5,1,ts(today-timedelta(days=40)),ts(today-timedelta(days=10)),'expired'),
        (6,6,1,ts(today-timedelta(days=5)),ts(today+timedelta(days=25)),'frozen'),
        (7,7,3,ts(today-timedelta(days=200)),ts(today+timedelta(days=165)),'active'),
        (8,8,2,ts(today-timedelta(days=95)),ts(today-timedelta(days=5)),'expired'),
        (9,9,1,ts(today-timedelta(days=2)),ts(today+timedelta(days=28)),'active'),
        (10,10,4,ts(today-timedelta(days=20)),ts(today+timedelta(days=10)),'active'),
        (11,11,1,ts(today-timedelta(days=10)),ts(today+timedelta(days=20)),'active'),
        (12,12,4,ts(today-timedelta(days=7)),ts(today+timedelta(days=23)),'active')])
    # занятия: блок прошлого месяца / текущей недели / будущее
    S = [
        (1,1,1,1, ts(fom-timedelta(days=11),18),60,3,'completed'),
        (2,3,1,3, ts(fom-timedelta(days=10),19),60,8,'completed'),
        (3,5,1,2, ts(fom-timedelta(days=9),18),45,5,'completed'),
        (4,4,2,4, ts(fom-timedelta(days=8),10),50,6,'completed'),
        (5,2,3,5, ts(fom-timedelta(days=7),20),55,10,'completed'),
        (6,1,2,1, ts(mon+timedelta(days=1),18),60,4,'completed'),
        (7,5,1,5, ts(mon+timedelta(days=2),19),45,8,'scheduled'),
        (8,3,1,3, ts(mon+timedelta(days=3),20),60,8,'scheduled'),
        (9,4,3,4, ts(today+timedelta(days=3),18),50,2,'scheduled'),
        (10,2,1,2, ts(today+timedelta(days=4),19),55,10,'scheduled'),
        (11,5,2,5, ts(today+timedelta(days=5),18),45,6,'scheduled'),
        (12,1,2,1, ts(today+timedelta(days=6),9),60,4,'scheduled')]
    cur.executemany("INSERT INTO class_session VALUES(?,?,?,?,?,?,?,?)", S)
    B = [(1,1,'attended'),(1,2,'attended'),(1,3,'attended'),
         (2,1,'attended'),(2,2,'attended'),(2,4,'attended'),(2,5,'attended'),(2,6,'attended'),(2,7,'attended'),(2,11,'no_show'),
         (3,3,'attended'),(3,8,'attended'),(3,9,'attended'),
         (4,2,'attended'),(4,4,'attended'),
         (5,5,'attended'),(5,7,'attended'),(5,10,'attended'),
         (6,4,'confirmed'),(6,6,'confirmed'),
         (7,5,'confirmed'),(7,9,'confirmed'),(7,10,'confirmed'),(7,11,'cancelled'),
         (8,7,'confirmed'),(8,12,'confirmed'),
         (9,1,'confirmed'),(9,2,'confirmed'),(9,3,'waitlisted'),
         (10,4,'confirmed'),(11,5,'confirmed'),(12,6,'confirmed')]
    cur.executemany("INSERT INTO booking(session_id,member_id,status) VALUES(?,?,?)", B)
    P = [(7,7,28000, ts(add_months(fom,-4)+timedelta(days=3),12),'card'),
         (8,8,8000,  ts(add_months(fom,-3)+timedelta(days=5),12),'online'),
         (3,3,8000,  ts(add_months(fom,-3)+timedelta(days=12),12),'card'),
         (5,5,3000,  ts(add_months(fom,-2)+timedelta(days=2),12),'cash'),
         (1,1,28000, ts(add_months(fom,-2)+timedelta(days=9),12),'card'),
         (2,2,3000,  ts(add_months(fom,-1)+timedelta(days=4),12),'card'),
         (4,4,2000,  ts(add_months(fom,-1)+timedelta(days=6),12),'online'),
         (9,9,3000,  ts(add_months(fom,-1)+timedelta(days=20),12),'card'),
         (10,None,700,ts(add_months(fom,-1)+timedelta(days=22),12),'cash'),
         (6,6,3000,  ts(fom+timedelta(days=2),12),'card'),
         (10,10,2000,ts(fom+timedelta(days=4),12),'online'),
         (11,None,700,ts(fom+timedelta(days=6),12),'cash')]
    cur.executemany("INSERT INTO payment(member_id,membership_id,amount,paid_at,method) VALUES(?,?,?,?,?)", P)

def show(title, cur, sql):
    print("\n=== " + title + " ===")
    cur.execute(sql)
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    print(" | ".join(cols))
    for r in rows:
        print(" | ".join("" if v is None else str(v) for v in r))
    return rows

def main():
    con = sqlite3.connect(":memory:")
    con.execute("PRAGMA foreign_keys=ON")
    cur = con.cursor()
    cur.executescript(SCHEMA)
    seed(cur)
    con.commit()
    print("Схема создана, данные загружены. Проверки целостности:")

    # --- негативные проверки: ограничения обязаны срабатывать ---
    checks = []
    try:
        cur.execute("INSERT INTO booking(session_id,member_id,status) VALUES(1,1,'confirmed')")
        checks.append(("UNIQUE(session_id,member_id) — повтор брони", False))
    except sqlite3.IntegrityError:
        checks.append(("UNIQUE(session_id,member_id) — повтор брони отклонён", True))
    try:
        cur.execute("INSERT INTO review(member_id,session_id,rating) VALUES(1,1,7)")
        checks.append(("CHECK rating BETWEEN 1 AND 5", False))
    except sqlite3.IntegrityError:
        checks.append(("CHECK rating BETWEEN 1 AND 5 отклонил 7", True))
    try:
        cur.execute("INSERT INTO class_session VALUES(99,1,1,1,?,60,0,'scheduled')",
                    (ts(today+timedelta(days=40),12),))
        checks.append(("CHECK capacity>0", False))
    except sqlite3.IntegrityError:
        checks.append(("CHECK capacity>0 отклонил 0", True))
    con.rollback()  # откатываем негативные пробы
    for name, ok in checks:
        print(("  [OK]   " if ok else "  [FAIL] ") + name)

    # --- сложные запросы ---
    q7 = show("Q7: топ занятий по заполняемости за прошлый месяц", cur, """
        SELECT ct.name AS class_name, c.name AS club, s.start_at,
          SUM(CASE WHEN b.status IN('confirmed','attended') THEN 1 ELSE 0 END) AS booked,
          s.capacity,
          ROUND(100.0*SUM(CASE WHEN b.status IN('confirmed','attended') THEN 1 ELSE 0 END)/s.capacity,1) AS fill_pct,
          RANK() OVER (ORDER BY 1.0*SUM(CASE WHEN b.status IN('confirmed','attended') THEN 1 ELSE 0 END)/s.capacity DESC) AS rnk
        FROM class_session s
        JOIN class_type ct ON ct.class_type_id=s.class_type_id
        JOIN club c ON c.club_id=s.club_id
        LEFT JOIN booking b ON b.session_id=s.session_id
        WHERE strftime('%Y-%m', s.start_at) = strftime('%Y-%m', date('now','start of month','-1 day'))
        GROUP BY s.session_id, ct.name, c.name, s.start_at, s.capacity
        ORDER BY fill_pct DESC LIMIT 5;""")

    q8 = show("Q8: помесячная выручка + рост + нарастающий итог", cur, """
        WITH m AS (SELECT strftime('%Y-%m', paid_at) AS month, SUM(amount) AS revenue
                   FROM payment GROUP BY 1)
        SELECT month, revenue,
          LAG(revenue) OVER (ORDER BY month) AS prev_revenue,
          SUM(revenue) OVER (ORDER BY month) AS running_total
        FROM m ORDER BY month;""")

    q9 = show("Q9: бронировали, но ни разу не посетили", cur, """
        SELECT m.member_id, m.full_name FROM member m
        WHERE EXISTS(SELECT 1 FROM booking b WHERE b.member_id=m.member_id)
          AND NOT EXISTS(SELECT 1 FROM booking b WHERE b.member_id=m.member_id AND b.status='attended')
        ORDER BY m.member_id;""")

    q10 = show("Q10: загрузка тренеров за текущую неделю", cur, """
        WITH sess AS (
          SELECT trainer_id, COUNT(*) AS sessions, SUM(duration_min) AS minutes
          FROM class_session
          WHERE strftime('%Y-%W', start_at)=strftime('%Y-%W','now')
          GROUP BY trainer_id),
        cli AS (
          SELECT s.trainer_id, COUNT(DISTINCT b.member_id) AS clients
          FROM class_session s
          JOIN booking b ON b.session_id=s.session_id AND b.status IN('confirmed','attended')
          WHERE strftime('%Y-%W', s.start_at)=strftime('%Y-%W','now')
          GROUP BY s.trainer_id)
        SELECT t.full_name, sess.sessions, ROUND(sess.minutes/60.0,2) AS hours,
               COALESCE(cli.clients,0) AS clients
        FROM trainer t
        JOIN sess ON sess.trainer_id=t.trainer_id
        LEFT JOIN cli ON cli.trainer_id=t.trainer_id
        ORDER BY hours DESC;""")

    # --- автопроверки ожиданий ---
    print("\n=== ИТОГ ПРОВЕРОК ===")
    ok = True
    cond1 = len(q7) >= 5 and abs(q7[0][5]-100.0) < 0.01
    cond2 = len(q8) == 5
    cond3 = sorted(r[0] for r in q9) == [11,12]
    cond4 = len(q10) >= 1
    for name, c in [("Q7 топ-5, лидер 100%", cond1),
                    ("Q8 ровно 5 месяцев", cond2),
                    ("Q9 это клиенты 11 и 12", cond3),
                    ("Q10 загрузка недели не пуста", cond4)]:
        print(("  [OK]   " if c else "  [FAIL] ") + name)
        ok = ok and c
    print("\nРЕЗУЛЬТАТ:", "ВСЁ ПРОШЛО" if ok else "ЕСТЬ ОШИБКИ")

if __name__ == "__main__":
    main()
