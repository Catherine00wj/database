-- COMP9311 17s1 Project 2
--
-- Section 1 Template

--Q1: ...
create type IncorrectRecord as (pattern_number integer, uoc_number integer);

create or replace function Q1(pattern text, uoc_threshold integer) 
	returns IncorrectRecord as $$
    declare aaa IncorrectRecord;
begin
	aaa.pattern_number = code_number($1);
	aaa.uoc_number = uoc_number($2 , $1);
    return aaa;
end;
$$ language plpgsql;

create or replace function code_number(code_s text) returns integer as $$
declare code_nb integer;
begin
     select count(code) into code_nb 
     from subjects
     where eftsload *48 != uoc
     and code like $1 
     ;
     return code_nb;
end;
$$ language plpgsql;

create or replace function uoc_number(uoc_s integer , code_s text) returns integer as $$
declare uoc_nb integer;
begin
     select count(id) into uoc_nb
     from subjects
     where eftsload * 48 != uoc
     and code like $2
     and uoc > $1 
     ;
     return uoc_nb;
end;
$$ language plpgsql;


-- Q2: ...
create type TranscriptRecord as (cid integer, term char(4), code char(8), name text, uoc integer, mark integer, grade char(2), rank integer, totalEnrols integer);

create or replace function Q2(stu_unswid integer)
	returns setof TranscriptRecord
as $$
declare rec TranscriptRecord %rowtype;
begin
     for rec in  ((select cid as cid, term as term, code as code, name as name, uoc as uoc, mark as mark, grade as grade, rank as rank, totalEnrols as totalEnrols
     from table_6
     where table_6.unswid = $1
     and table_6.grade in ('SY', 'RS', 'PT', 'PC', 'PS', 'CR', 'DN', 'HD', 'A', 'B', 'C', 'D', 'E'))
     union
     (select cid as cid, term as term, code as code, name as name, 0 as uoc, mark as mark, grade as grade, rank as rank, totalEnrols as totalEnrols
     from table_6
     where table_6.unswid = $1
     and table_6.grade not in ('SY', 'RS', 'PT', 'PC', 'PS', 'CR', 'DN', 'HD', 'A', 'B', 'C', 'D', 'E')))
     order by cid
     loop
 return next rec;
 end loop;
end;
$$ language plpgsql;


create or replace view table_1 as
select c.id as cid, (right(se.year::text,2)||lower(se.term)) as term, s.code, s.name, s.uoc, ce.mark, ce.grade,p.unswid
from people p, course_enrolments ce, courses c,subjects s,semesters se
where p.id = ce.student
and ce.course = c.id
and c.subject = s.id
and c.semester = se.id;

create or replace view table_2 as
select course,count(student) 
from course_enrolments ce 
where mark is not null 
group by course;

create or replace view table_3 as
select courses.id,courses.subject, courses.semester,table_2.count,coalesce(count,0)
from courses left join table_2
on table_2.course = courses.id;

create or replace view table_4 as
select t.cid, t.term, t.code, t.name, t.uoc, t.mark, t.grade,t.unswid,ta.coalesce as totalEnrols 
from table_1 t left join  table_3 ta
on t.cid = ta.id;

create or replace view table_5 as
select unswid , cid, rank() over(partition by cid order by mark desc)
from table_4
where mark is not null;

create or replace view table_6 as
select t.cid, t.term, t.code, t.name, t.uoc, t.mark, t.grade,t.unswid,t.totalEnrols,ta.rank
from table_4 t left join  table_5 ta 
on t.unswid = ta.unswid and t.cid = ta.cid;


--... SQL statements, possibly using other views/functions defined by you ...



-- Q3: ...
create type TeachingRecord as (unswid integer, staff_name text, teaching_records text);
create or replace function Q3_1(org_id integer, num_sub integer, num_times integer)
        returns table(unswid integer, staff_name text, teaching_records text) as $$
        with
recursive A as (select * from orgunit_groups og where og.owner = $1
                        union all select og.* from orgunit_groups og ,A where og.owner = A.member),


B as (select s.id as role,s.name as course_name , p.id, p.name ,p.unswid, cs.course,c.subject,su.offeredby,su.code
           from people p, staff_roles s, courses c, course_staff cs, subjects su
           where s.id = cs.role
           and cs.course = c.id
           and cs.staff = p.id
           and c.subject = su.id
           and s.name != '%tutor%'),
C AS (select A.*,B.* from A inner join B on A.member= B.offeredby),
D as (SELECT count (distinct subject) as subject_count,unswid
      FROM c
      group by unswid
      having count(distinct subject)>$2),

E as (select C.*,D.subject_count from C inner join D on D.unswid = C.unswid),

F as (SELECT DISTINCT  count(subject) as time_count,E.unswid,o.name as school,E.name,E.code,subject
      FROM E INNER JOIN orgunits o
      ON E.offeredby = o.id
      group by subject,E.unswid,o.name,E.name,E.code
      having count( subject)>$3
      order by subject)

select unswid, name as staff_name, string_agg(code||', '||time_count||', '||school ,chr(10))||chr(10) as teaching_recording
from F
group by unswid,name
order by name;
$$ language sql;
create or replace function Q3(org_id integer, num_sub integer, num_times integer) 
	returns setof TeachingRecord as $$
begin
	return query select q3_1.unswid, q3_1.staff_name, q3_1.teaching_records as teaching_records
	from (select * from q3_1($1,$2,$3)) q3_1;

end;
--... SQL statements, possibly using other views/functions defined by you ...
$$ language plpgsql;

