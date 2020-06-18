use blue_bikes;

select distinct usertype from september_2019;

select * from august_2019;

select 
	*
from colleges_boston;

select * from stations where district = 'boston';

select count(*) 
from parcels_2017;

drop table colleges_parcels;


	create table colleges_parcels as
	select 
		parcels_2017.ZIPCODE, 
		parcels_2017.owner, 
		parcels_2017.full_address
	from parcels_2017
	join colleges_boston on parcels_2017.owner like concat("%", colleges_boston.Name, "%");


select count(*) from colleges_parcels;


select *
from college_parcels_geocodio;

select * 
from stations;

select distinct `start station id` from august_2019;

select 
	starttime, 
    stoptime, 
    august_2019.`start station id`
	ifnull(start_station.name, concat("WAS NULL", `start station name`)) as 'start_station_name', 
    ifnull(end_station.name, concat("WAS NULL", `end station name`)) as 'end_station_name'
from august_2019
left join stations as start_station on august_2019.`start station name` = start_station.Name
left join stations as end_station on august_2019.`end station name` = end_station.Name;


select distinct blue_bikes.august_2019.`start station name`, blue_bikes.august_2019.`start station latitude`, blue_bikes.august_2019.`start station longitude`
from blue_bikes.august_2019
where blue_bikes.august_2019.`start station name` not in (select blue_bikes.stations.name from blue_bikes.stations);

select gender, count(*) 
from august_2019 
group by gender
order by count(*) desc;

select gender, count(*) 
from september_2019 
group by gender
order by count(*) desc;

-- ugh
select distinct `birth year` as y
from blue_bikes.july_2019
having y < 1901 or y > 2155;

use college_blue_bikes;
select * from station;