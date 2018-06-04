ROLLBACK;

DROP TABLE IF EXISTS sign_a_bond;
DROP FUNCTION IF EXISTS signing;
DROP TABLE IF EXISTS services_of_companies;
DROP TABLE IF EXISTS ins_bonds;
DROP TABLE IF EXISTS ins_services;
DROP TABLE IF EXISTS ins_companies;
DROP TABLE IF EXISTS cars;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
	id SERIAL PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    salary INTEGER NOT NULL,
    CONSTRAINT email_not_empty CHECK (email <> ''),
    CONSTRAINT salary_not_negative CHECK (salary >= 0)
);

CREATE TABLE cars (
	id SERIAL PRIMARY KEY,
	license_plate TEXT UNIQUE NOT NULL,
	manufacturer TEXT NOT NULL,
	model TEXT NOT NULL,
	CONSTRAINT license_not_empty CHECK (license_plate <> ''),
	CONSTRAINT manufacturer_not_empty CHECK (manufacturer <> ''),
	CONSTRAINT model_not_empty CHECK (model <> '')
);

CREATE TABLE ins_companies (
	id SERIAL PRIMARY KEY,
	company_name TEXT UNIQUE NOT NULL,
	CONSTRAINT name_not_empty CHECK (company_name <> '')
);

CREATE TABLE ins_services (
	id SERIAL PRIMARY KEY,
	service_name TEXT UNIQUE NOT NULL,
	min_salary INTEGER NOT NULL,
	length INTEGER NOT NULL,
	issuer TEXT NOT NULL,
	CONSTRAINT name_not_empty CHECK (service_name <> ''),
	CONSTRAINT min_salary_not_negative CHECK (min_salary >= 0),
	CONSTRAINT length_at_least_one CHECK (length >= 1),
	FOREIGN KEY (issuer) REFERENCES ins_companies(company_name) ON DELETE CASCADE
);

CREATE TABLE ins_bonds (
	id SERIAL PRIMARY KEY,
	issued_date INTEGER NOT NULL
);

CREATE TABLE services_of_companies (
	company_id SERIAL,
	service_id SERIAL,
	FOREIGN KEY (company_id) REFERENCES ins_companies(id) ON DELETE CASCADE,
	FOREIGN KEY (service_id) REFERENCES ins_services(id) ON DELETE CASCADE
);

CREATE TABLE sign_a_bond (
	user_id SERIAL,
	car_id SERIAL UNIQUE,
	company_id SERIAL,
	service_id SERIAL,
	bond_id SERIAL,
	FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
	FOREIGN KEY (car_id) REFERENCES cars(id) ON DELETE RESTRICT,
	FOREIGN KEY (company_id) REFERENCES ins_companies(id) ON DELETE RESTRICT,
	FOREIGN KEY (service_id) REFERENCES ins_services(id) ON DELETE RESTRICT,
	FOREIGN KEY (bond_id) REFERENCES ins_bonds(id) ON DELETE RESTRICT
);

CREATE FUNCTION signing() RETURNS trigger AS $signing$
    BEGIN
        IF (SELECT salary FROM users WHERE id = NEW.user_id) < (SELECT min_salary FROM ins_services WHERE id = NEW.service_id) THEN
            RAISE EXCEPTION 'You have no money for this service';
        END IF;
		INSERT INTO ins_bonds (issued_date) VALUES
			(2018);
		NEW.bond_id = (SELECT currval('ins_bonds_id_seq'));
        RETURN NEW;
    END;
$signing$ LANGUAGE plpgsql;

CREATE TRIGGER signing BEFORE INSERT OR UPDATE ON sign_a_bond
    FOR EACH ROW EXECUTE PROCEDURE signing();

--Add new user
BEGIN;
INSERT INTO users (email, salary) VALUES
	('user1@user1.com', 0),		--1
    ('user2@user2.com', 1000),	--2
    ('user3@user3.com', 2500),	--3
    ('user4@user4.com', 4000),	--4
	('user5@user5.com', 0);		--5
COMMIT;

--List users
BEGIN;
SELECT email FROM users;
COMMIT;

--User details
BEGIN;
SELECT * FROM users;
COMMIT;

--Delete existing user
BEGIN;
DELETE FROM users WHERE id IN (SELECT id FROM users) AND id = 1;
COMMIT;

--List users with no salary
BEGIN;
SELECT email FROM users WHERE salary = 0;
COMMIT;

--Add new car
BEGIN;
INSERT INTO cars (license_plate, manufacturer, model) VALUES
	('AAA-111', 'Ford', 'Focus'),		--1
    ('BBB-222', 'Dodge', 'Charger'),	--2
    ('CCC-333', 'Fiat', 'Polski'),		--3
    ('DDD-444', 'Renault', 'Megane'),	--4
	('EEE-555', 'Audi', 'R8');			--5
COMMIT;

--List cars
BEGIN;
SELECT manufacturer, model FROM cars;
COMMIT;

--List insured cars
BEGIN;
SELECT license_plate, manufacturer, model FROM cars WHERE id IN (SELECT car_id FROM sign_a_bond);
COMMIT;

--List uninsured cars
BEGIN;
SELECT license_plate, manufacturer, model FROM cars WHERE id NOT IN (SELECT car_id FROM sign_a_bond);
COMMIT;

--Delete existing car
BEGIN;
DELETE FROM cars WHERE id IN (SELECT id FROM cars) AND id = 1;
COMMIT;

--Add new insurance company
BEGIN;
INSERT INTO ins_companies (company_name) VALUES
	('NO comapny'),		--1
	('Insure Masters'),	--2
	('K&H'),			--3
	('Super Insurers');	--4
INSERT INTO ins_services (service_name, min_salary, length, issuer) VALUES
	('No service', 0, 1, 'K&H'),			--1
	('chaos', 500, 1, 'Super Insurers'),	--2
	('ultimate', 1500, 2, 'Insure Masters'),--3
	('best', 2000, 3, 'K&H');				--4
COMMIT;

--List insurance companies
BEGIN;
SELECT * FROM ins_companies;
COMMIT;

--Delete existing insurance company
BEGIN;
DELETE FROM ins_companies WHERE id IN (SELECT id FROM ins_companies) AND id = 1;
COMMIT;

--Add new insurance service
BEGIN;
INSERT INTO ins_services (service_name, min_salary, length, issuer) VALUES
	('required', 500, 1, 'Insure Masters'),	--5
	('Casco', 1500, 2, 'K&H'),				--6
	('SaveU', 2000, 3, 'Super Insurers');	--7
COMMIT;

--List insurance services
BEGIN;
SELECT * FROM ins_services;
COMMIT;

--List insurance company services
BEGIN;
SELECT issuer, service_name, min_salary, length FROM ins_services
	JOIN ins_companies ON ins_services.issuer = ins_companies.company_name
	WHERE issuer ILIKE '%insure%'
	ORDER BY issuer;
COMMIT;

--Delete an existing insurance service
BEGIN;
DELETE FROM ins_services WHERE id IN (SELECT id FROM ins_services) AND id = 1;
COMMIT;

--Insure car
BEGIN;
INSERT INTO sign_a_bond (user_id, car_id, company_id, service_id) VALUES
	(3, 2, 2, 3);
COMMIT;

--Lengthen insurance bond
BEGIN;
UPDATE ins_bonds SET issued_date = issued_date + 3 WHERE id = 1;
COMMIT;

--List invalid insurance bonds
BEGIN;
SELECT 
	(SELECT email FROM users WHERE id = user_id) AS user_email,
	(SELECT license_plate FROM cars WHERE id = car_id) AS car_license_plate,
	(SELECT company_name FROM ins_companies WHERE id = company_id) AS company_name,
	(SELECT service_name FROM ins_services WHERE id = service_id) AS service_name,
	(SELECT issued_date FROM ins_bonds WHERE id = bond_id) AS date_of_issue
	FROM sign_a_bond WHERE (SELECT issued_date FROM ins_bonds WHERE id = bond_id) < 2018;
COMMIT;

--List valid insurance bonds
BEGIN;
SELECT 
	(SELECT email FROM users WHERE id = user_id) AS user_email,
	(SELECT license_plate FROM cars WHERE id = car_id) AS car_license_plate,
	(SELECT company_name FROM ins_companies WHERE id = company_id) AS company_name,
	(SELECT service_name FROM ins_services WHERE id = service_id) AS service_name,
	(SELECT issued_date FROM ins_bonds WHERE id = bond_id) AS date_of_issue
	FROM sign_a_bond WHERE (SELECT issued_date FROM ins_bonds WHERE id = bond_id) >= 2018;
COMMIT;

--List number of insurance bonds issued by companies
BEGIN;

COMMIT;