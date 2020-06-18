drop database if exists college_blue_bikes;
create database college_blue_bikes;

use college_blue_bikes;

-- Creating simple key and value tables for usertype and gender.
drop table if exists usertype;
create table usertype (
	usertype_id int primary key auto_increment,
    usertype varchar(45) not null unique
) as select distinct usertype from blue_bikes.september_2019;

insert into usertype (usertype)
select distinct blue_bikes.july_2019.usertype from blue_bikes.july_2019 where blue_bikes.july_2019.usertype not in (select usertype.usertype from usertype);

drop table if exists gender;
create table gender (
	gender_id int primary key,
    gender_name varchar(45) unique
) as select distinct gender as gender_id from blue_bikes.september_2019;

update gender
set gender_name = "male"
where gender_id = 1;

update gender
set gender_name = "female"
where gender_id = 2;

update gender
set gender_name = "unspecified"
where gender_id = 0;


drop table if exists station;
create table station (
	station_id int primary key auto_increment,
    name varchar(255),
    latitude double,
    longitude double,
    is_public tinyint default true,
    total_docks int default null
) as select name, latitude, longitude, if(public = 'Yes', 1, 0) as is_public, `total docks` as total_docks 
	from blue_bikes.stations where district = 'Boston';
    
-- ensure we have all the stations in the months we are looking at
insert into station (name, latitude, longitude)
(
	select distinct blue_bikes.july_2019.`start station name`, blue_bikes.july_2019.`start station latitude`, blue_bikes.july_2019.`start station longitude`
	from blue_bikes.july_2019
	where blue_bikes.july_2019.`start station name` not in (select college_blue_bikes.station.name from college_blue_bikes.station)
);

insert into station (name, latitude, longitude)
(
	select distinct blue_bikes.july_2019.`end station name`, blue_bikes.july_2019.`end station latitude`, blue_bikes.july_2019.`end station longitude`
	from blue_bikes.july_2019
	where blue_bikes.july_2019.`end station name` not in (select college_blue_bikes.station.name from college_blue_bikes.station)
);

insert into station (name, latitude, longitude)
(
	select distinct blue_bikes.september_2019.`start station name`, blue_bikes.september_2019.`start station latitude`, blue_bikes.september_2019.`start station longitude`
	from blue_bikes.september_2019
	where blue_bikes.september_2019.`start station name` not in (select college_blue_bikes.station.name from college_blue_bikes.station)
);

insert into station (name, latitude, longitude)
(
	select distinct blue_bikes.september_2019.`end station name`, blue_bikes.september_2019.`end station latitude`, blue_bikes.september_2019.`end station longitude`
	from blue_bikes.september_2019
	where blue_bikes.september_2019.`end station name` not in (select college_blue_bikes.station.name from college_blue_bikes.station)
);
    

drop table if exists trip;
create table trip (
	trip_id int primary key auto_increment,
    start_time datetime not null,
    end_time datetime not null,
    start_station_id int,
    end_station_id int,
    bike_id varchar(45),
    dob int, -- this would be type year if it wasn't restricted to greater than 1901
    usertype_id int not null,
    gender_id int not null,
    
    constraint trip_fk_usertype
		foreign key (usertype_id)
        references college_blue_bikes.usertype (usertype_id),
	constraint trip_fk_gender
		foreign key (gender_id)
        references gender (gender_id),
    
    constraint trip_fk_start_station
		foreign key (start_station_id)
        references station (station_id),
	constraint trip_fk_end_station
		foreign key (end_station_id)
        references station (station_id)
);

insert into trip (start_time, end_time, start_station_id, end_station_id, bike_id, dob, usertype_id, gender_id)
select 
	starttime, 
	stoptime, 
	(select station_id from station where station.name like blue_bikes.july_2019.`start station name`),
	(select station_id from station where station.name like blue_bikes.july_2019.`end station name`),
	bikeid,
	`birth year`,
    (select college_blue_bikes.usertype.usertype_id from college_blue_bikes.usertype where blue_bikes.july_2019.usertype = college_blue_bikes.usertype.usertype) as usertype_result,
	(select gender_id from gender where blue_bikes.july_2019.gender = gender.gender_id)
from blue_bikes.july_2019
having usertype_result in (select usertype.usertype_id from usertype);

insert into trip (start_time, end_time, start_station_id, end_station_id, bike_id, usertype_id, dob, gender_id)
select 
	starttime, 
	stoptime, 
	(select station_id from station where station.name like blue_bikes.september_2019.`start station name`),
	(select station_id from station where station.name like blue_bikes.september_2019.`end station name`),
	bikeid,
	(select usertype_id from usertype where blue_bikes.september_2019.usertype = usertype.usertype) as usertype_result,
	`birth year`,
	(select gender_id from gender where blue_bikes.september_2019.gender = gender.gender_id)
from blue_bikes.september_2019
having usertype_result in (select usertype.usertype_id from usertype);

-- College table
drop table if exists college;
create table college (
	college_id int primary key auto_increment,
    name varchar(255) not null,
    address varchar(255),
    city varchar(45), -- this refers to the subneighborhoods in boston (eg Fenway)
    zipcode int,
    num_students int,
    latitude double, 
    longitude double    
);

insert into college (name, address, city, zipcode, num_students, latitude, longitude)
select name, address, city, zipcode, numstudent, latitude, longitude from blue_bikes.colleges_boston;

-- Parcel table
drop table if exists parcel;
create table parcel (
	parcel_id int primary key auto_increment,
    zipcode int,
    owned_by int not null,
    full_address varchar(255),
    latitude double,
    longitude double,
    accuracy_score double,
    
    constraint parcel_fk_college
		foreign key (owned_by)
		references college (college_id) 
);

insert into parcel (zipcode, owned_by, full_address, latitude, longitude, accuracy_score)
select 
	distinct zipcode, 
    (select college.college_id from college where blue_bikes.college_parcels_geocodio.owner like college.name) as college_id, 
    full_address,
    latitude,
    longitude,
    `accuracy score`
from blue_bikes.college_parcels_geocodio
having college_id is not null;