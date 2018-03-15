-- COMP9311 17s1 Project 1
--
-- MyMyUNSW Solution Template


-- Q1: buildings that have more than 30 rooms
create or replace view Q1(unswid, name)
as
SELECT distinct buildings.unswid,  Buildings.name
FROM Buildings , Rooms
WHERE  Buildings.id in
       (select Rooms.building
        from rooms,buildings
         where buildings.id = rooms.building
        GROUP BY rooms.building
        having count (rooms.building)>30)
--... SQL statements, possibly using other views/functions defined by you ...
;



-- Q2: get details of the current Deans of Faculty
create or replace view Q2(name, faculty, phone, starting)
as
SELECT p.name, o.longname ,s.phone, a.starting
FROM people p, orgunits o, staff s, affiliations a, staff_roles r, orgunit_types t
WHERE r.name = 'Dean'
AND a.role = r.id
AND a.staff= s.id
AND s.id = p.id
AND a.orgUnit = o.id
AND a.ending is null
AND t.name = 'Faculty'
AND o.utype = t.id
;

--... SQL statements, possibly using other views/functions defined by you ...



-- Q3: get details of the longest-serving and shortest-serving current Deans of Faculty
create or replace view Q3(status, name, faculty, starting)
as
SELECT
CASE
WHEN starting in (select max(starting) from Q2 ) then 'Shortest serving'::text
WHEN starting in (select min(starting) from Q2 ) then'Longest serving'::text
END AS status, q.name, q.faculty, q.starting
FROM  Q2 q
WHERE starting IN (SELECT max(starting) from Q2) OR
starting IN (select min(starting)
                   FROM Q2)

--... SQL statements, possibly using other views/functions defined by you ...
;



-- Q4 UOC/ETFS ratio
create or replace view Q4(ratio,nsubjects)
as

SELECT distinct((s.uoc/s.eftsload) ::numeric (4,1)),COUNT(s.uoc/s.eftsload)
FROM Subjects s
WHERE ((s.eftsload is  not NULL )
and (s.eftsload != 0))
GROUP BY (s.uoc/s.eftsload) ::numeric (4,1)
--... SQL statements, possibly using other views/functions defined by you ...
;



-- Q5: program enrolment information from 10s1
create or replace view Q5a(num)
as
select count(t.id)  
from students t,program_enrolments p,stream_enrolments r,streams s,semesters q
where 
t.stype = 'intl'
and t.id = p.student
and p.id= r.partof
and r.stream = s.id
and s.code = 'SENGA1'
and q.id = p.semester
and q.id in (select q.id 
             from semesters q
             where (q.year = '2010' and q.term = 'S1'))
Group by t.styp
--... SQL statements, possibly using other views/functions defined by you ...
;

create or replace view Q5b(num)
as
select count(t.id)  
from students t,program_enrolments p,semesters q,programs o 
where 
t.stype = 'local'
and t.id = p.student
and p.program = o.id
and o.code = '3978'
and q.id = p.semester
and q.id in (select q.id 
             from semesters q
             where (q.year = '2010' and q.term = 'S1'))
Group by t.stype
--... SQL statements, possibly using other views/functions defined by you ...
;

create or replace view Q5c(num)
as
select count(t.id)  
from students t,program_enrolments p,semesters q,programs o ,orgunits s
where 
t.id = p.student
and p.program = o.id
and o.offeredby = s.id
and s.name = 'Faculty of Engineering'
and q.id = p.semester
and q.id in (select q.id 
             from semesters q
             where (q.year = '2010' and q.term = 'S1'))
Group by s.name
--... SQL statements, possibly using other views/functions defined by you ...
;



-- Q6: course CodeName
create or replace function Q6(text) returns text as $$
declare name text;
begin
select S.name into name
from subjects S
where ( code = $1);
return $1 || ' '|| name;
end;

--... SQL statements, possibly using other views/functions defined by you ...
$$ language plpgsql;



-- Q7: Percentage of growth of students enrolled in Database Systems
create or replace view studentcount as
select count(course_enrolments.student),semesters.year,semesters.term ,LAG(count(course_enrolments.student)) OVER (ORDER BY semesters.year) AS previouscount
from course_enrolments ,semesters,courses,subjects
where semesters.id = courses.semester
and courses.subject = subjects.id
and course_enrolments.course = courses.id
and subjects.name = 'Database Systems'
group by semesters.year,semesters.term


create or replace view Q7(year, term, perc_growth)
as
select s.year,s.term, (s.count::float/s.previouscount::float)::numeric(4,2) as perc_growth
from studentcount s
where (s.count::float/s.previouscount::float)::numeric(4,2) is not null

--... SQL statements, possibly using other views/functions defined by you ...
;



-- Q8: Least popular subjects
create or replace view find_subject as
select subjects.id as subject
from subjects,(select count(courses.id) as count_num,subjects.id as subject from subjects,courses where subjects.id = courses.subject group by courses.subject,subjects.id) count_nb
where count_nb.count_num >= 20
and subjects.id = count_nb.subject


create or replace view aaa as
select courses.id ,find_subject.subject,semesters.starting,row_number() over( partition by find_subject.subject order by semesters.starting desc) as index  
from courses,find_subject,semesters
where find_subject.subject = courses.subject
and courses.semester = semesters.id
group by courses.id ,semesters.starting,find_subject.subject


create or replace view bbb as
select   aaa.id ,aaa.subject,aaa.starting,count(aaa.id),aaa.index 
from   aaa   left   join   course_enrolments     
on   aaa.id=course_enrolments.course 
group by aaa.id ,aaa.subject,aaa.starting,aaa.index
having index <= 20
order by aaa.subject,aaa.starting desc


create or replace view ccc as
select bbb.subject
from bbb
group by subject
having max(count) < 20

create or replace view Q8(subject)
as
select subjects.code || ' ' ||subjects.name as subject
from ccc , subjects
where ccc.subject = subjects.id

--... SQL statements, possibly using other views/functions defined by you ...
;



-- Q9: Database Systems pass rate for both semester in each year
create or replace view studentmark as
select c.student,c.mark,s.semester
from course_enrolments c,courses s,subjects j
where c.course = s.id
and j.id = s.subject
and j.name = 'Database Systems'

create or replace view studentsemester as
select count(student) ,semester
from studentmark
where mark >= 50
group by semester

create or replace view student0 as
select count(student) ,semester
from studentmark
where mark >=0
group by semester


create create or replace view final_table as
select c.count  as count1,year ,term ,b.count as count2 
from semesters a,student0 b,studentsemester c
where a.id = b.semester
and a.id = c.semester

create or replace view semester2 as
select year ,term,(count1::float/count2::float)::numeric(4,2) as perc_pass
from final_table
where term = 'S2'

create or replace view semester1 as
select year ,term,(count1::float/count2::float)::numeric(4,2) as perc_pass
from final_table
where term = 'S1'

create or replace view Q9(year, s1_pass_rate, s2_pass_rate)
as
select distinct(semester1.year) , semester1.perc_pass ,semester2.perc_pass
from semester1,semester2
wheresemester1.year = semester2.year


--... SQL statements, possibly using other views/functions defined by you ...
;



-- Q10: find all students who failed all black series subjects
create or replace view fff as
select  s.id , e.year ,e.term
from subjects s, courses c, semesters e
where code like 'COMP93%'
and s.id = c.subject
and c.semester = e.id

create or replace view ggg as 
select count(id) , id
from fff
group by id
having count(id) = 24


create or replace view hhh as
select c.student,c.course,c.mark
from course_enrolments c , courses s, ggg 
where ggg.id = s.subject
and s.id = c.course
and mark < 50


create or replace view jjj as
select count(id) ,student
from hhh
group by student
having count(id) >= 2

create or replace view kkk as
select hhh.id ,hhh.student
from hhh ,jjj
where hhh.student= jjj.student
and hhh.id ='4897'

create or replace view Q10(zid, name)
as
select distinct 'z'||unswid as zid,family ||' '||given as name
from people,kkk
where people.id = kkk.student


--... SQL statements, possibly using other views/functions defined by you ...
;



