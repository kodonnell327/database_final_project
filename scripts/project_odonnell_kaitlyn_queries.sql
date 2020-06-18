use college_blue_bikes;

drop function if exists get_dist;
drop procedure if exists near_parcel;
drop procedure if exists near_university;

drop table if exists near_parcel_result;
drop table if exists near_university_result;

delimiter //
-- function for calculating the distance between two lat, long pairs
create function get_dist(lat1 double, long1 double, lat2 double, long2 double)
returns double -- dist in meters
deterministic
begin
	-- using the haversine formula to calculate distance as the crow flies over the earth's surface
	declare earth_radius double;    
    declare lat1_rads double;
    declare lat2_rads double;
    declare delta_lat double;
    declare delta_long double;
    declare a double;
    declare c double;
    declare dist double;
    
    set earth_radius = 6371000; -- meters
    
    -- mult by pi and divide by 180 to convert to radians
    set lat1_rads = lat1 * pi() / 180;
    set lat2_rads = lat2 * pi() / 180;
    
    set delta_lat = lat2_rads - lat1_rads;
    set delta_long = (long2 - long1) * pi() / 180;
    
    set a = (sin(delta_lat / 2) * sin(delta_lat / 2)) 
		+ (cos(lat1_rads) * cos(lat2_rads) * sin(delta_long / 2) * sin(delta_long / 2));
    
    set c = 2 * atan2(sqrt(a), sqrt(1-a));
    
    return earth_radius * c;
    
end //

-- procedure to get nearby blue bikes stations to given parcel id
-- max_dist in meters
create procedure near_parcel(parcel_id int, max_dist double)
begin
	declare parcel_lat double;
    declare parcel_long double;
    
    
    set parcel_lat = (select latitude from parcel where parcel.parcel_id = parcel_id);
    set parcel_long = (select longitude from parcel where parcel.parcel_id = parcel_id);
    
    drop table if exists near_parcel_result;
    create table near_parcel_result (
		station_id int,
        name varchar(255),
        latitude double,
        longitude double,
        is_public tinyint,
        total_docks int
    ) as select *
		from station
		where get_dist(parcel_lat, parcel_long, station.latitude, station.longitude) <= max_dist;
end //

-- procedure to get nearby blue bikes stations for given university id
create procedure near_university(university_id int, max_dist double)
begin
	drop table if exists near_university_result;
	create table near_university_result (
		parcel_id int,
		station_id int,
		station_name varchar(255),
		station_latitude double,
		station_longitude double,
		
		constraint near_uni_fk_parcel
			foreign key (parcel_id)
			references parcel (parcel_id),
		constraint near_uni_fk_station
			foreign key (station_id)
			references station (station_id)
	) as 
		select 
			parcel_id, 
			station_id, 
			station.name as station_name, 
			station.latitude as station_latitude, 
			station.longitude as station_longitude 
		from parcel 
		join station on get_dist(parcel.latitude, parcel.longitude, station.latitude, station.longitude) <= max_dist
		where owned_by = university_id and accuracy_score > 0.5;
end //
delimiter ;

-- tests for function and procedures
-- seems good, this distance is 0.3694km
select get_dist(42.3496094533, -71.103915237, 42.350406, -71.108279);

-- near parcel creates table
call near_parcel(2, 500);
select * from near_parcel_result;

-- also good, creates the table properly
call near_university(2, 500);
select * from near_university_result;


-- actual queries ----------------------

-- How many parcels are there for each university? Ordered by most parcels to least.
select college.name, count(*) as 'parcel_count'
from parcel 
join college on parcel.owned_by = college_id
group by owned_by
order by parcel_count desc;

-- What are the very nearby bluebike stations for Northeastern (within 100 meters of an owned parcel)?
call near_university((select college_id from college where college.name = "Northeastern University"), 100);
select distinct station_id, station_name, station_latitude, station_longitude from near_university_result;

-- How many trips do these blue bike stations see during BOTH july and august (ie the whole trip table)?
select near_university_result.station_name, count(*) as 'num_trips'
from trip
join near_university_result on near_university_result.station_id in (trip.start_station_id, trip.end_station_id)
group by near_university_result.station_name
order by num_trips desc;

-- How many trips do these blue bike stations see during July vs September (separate counts for each month)
select 
	near_university_result.station_name, 
	sum(case when month(trip.start_time) = 7 then 1 else 0 end) as count_july, 
    sum(case when month(trip.start_time) = 9 then 1 else 0 end) as count_september
from trip
join near_university_result on near_university_result.station_id in (trip.start_station_id, trip.end_station_id)
group by near_university_result.station_name;


-- Do blue bike stations generally see an increase in trips from july to september? 

select * from (
	select 
		stations_near_unis.college_name,
		sum(case when month(trip.start_time) = 7 then 1 else 0 end) as 'count_july', 
		sum(case when month(trip.start_time) = 9 then 1 else 0 end) as 'count_september',
        stations_near_unis.num_students
	from trip
	join (
		select distinct 
			college.name as 'college_name', 
			college.num_students, 
			station_id, 
			station.latitude as station_latitude, 
			station.longitude as station_longitude 
		from parcel 
		join station on get_dist(parcel.latitude, parcel.longitude, station.latitude, station.longitude) <= 400
		join college on owned_by = college.college_id
		where accuracy_score > 0.5
	) stations_near_unis on stations_near_unis.station_id in (trip.start_station_id, trip.end_station_id)
    where trip.dob > 1995 
		and stations_near_unis.num_students > 0 
		and (select usertype.usertype from usertype where trip.usertype_id = usertype.usertype_id) = "Subscriber"
	group by stations_near_unis.college_name, stations_near_unis.num_students
) 
trip_counts order by count_september - count_july desc;

