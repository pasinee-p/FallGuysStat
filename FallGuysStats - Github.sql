USE FallGuysStat

select *
from FallGuysStat..FGstats

select *
from FallGuysStat..Rounds

--Delete excessive null rows
delete
from FallGuysStat..FGstats
where [Total rounds played] is null

--Change date time to date
alter table FGStats
	alter column Date date not null;

--Check all show types
select distinct ([Show type]) 
from FGstats
where [Show type] is not null

--Join 2 tables
select * 
from FGstats as f
LEFT JOIN Rounds as r
ON f.[Round name] = r.[Round name]

--=================================================--

--1. Find out which rounds are the most difficult to pass 

--No team/final rounds excluded 
--Calculated by elimination rate

drop view if exists view_Elim
GO
CREATE view view_Elim as 
	select [Total rounds played], s.[Round name], [Round type]
			, [Round category], [Total guys]
			, sum([Total guys]) over(partition by s.[Round name] order by [Total rounds played]) as TotalGuys
			, [Total guys] - [Qualified guys] as Eliminated
			, sum([Total guys] - [Qualified guys]) over(partition by s.[Round name] order by [Total rounds played]) as TotalEliminatedGuys
			--, (s.[Total guys] - s.[Qualified guys])/ s.[Total guys] * 100 as EliminatedPercentage
	from FGstats as s
	LEFT JOIN Rounds as r
	ON s.[Round name] = r.[Round name]
	where [Show type] in ('Main Show','Trick Show')
			and [Round type] <> 'team'
			and [Round category] <> 'Final'
			and [Qualified guys] is not null
GO

select [Round name], [Round type]
		, cast((MAX(TotalEliminatedGuys) / MAX(TotalGuys) *100 ) as decimal(5,2)) as EliminationRateByRound
from view_Elim
group by [Round name], [Round type]
order by EliminationRateByRound DESC


--=================================================--

--2. Determine my overall qualify rate per total rounds played

--Add a new column and change 'yes' to 1 and 'no' to from [Qualified?]
select [Round name], [Qualified?]
		, CASE WHEN [Qualified?] = 'yes' THEN 1
			   WHEN [Qualified?] = 'no' THEN 0
			   ELSE [Qualified?]
		  END
from FGstats
order by [Qualified?]

alter table FGstats
	add TimesQualified int;

UPDATE FGstats
SET TimesQualified = CASE WHEN [Qualified?] = 'yes' THEN 1
			   WHEN [Qualified?] = 'no' THEN 0
			   ELSE [Qualified?]
		  END

--Calculate overall qualify rate 
select sum(TimesQualified) as TotalTimesQualified
		, max([Total rounds played]) as TotalRoundPlayed
		, convert(decimal(5,2),(sum(TimesQualified)/max([Total rounds played])*100)) as OverallQualifiedRate
from FGstats

--=================================================--

--3. My qualified rate/ Eliminated rate by round (Final included)

select *
from FallGuysStat..FGstats

drop view if exists view_WinRate
GO
CREATE VIEW view_WinRate as
	select f.[Round name], f.[Qualified?], r.[Round category]
			, count([Qualified?]) as TimesQorE
	from FGstats as f
	LEFT JOIN Rounds as r
	ON r.[Round name] = f.[Round name]
	where f.[Round name] is not null
	group by f.[Round name], f.[Qualified?], r.[Round category]
GO

with cte_WinRate as(
		select *, sum(TimesQorE) 
					over(partition by [Round name] order by [Round name]) as Rounds_played
		from view_WinRate
)
select *, convert(decimal(5,2),cast(TimesQorE as decimal(5,2)) / cast(Rounds_played as decimal(5,2)) * 100)
			as WinLoseRatePerRound
from cte_WinRate
--where [Qualified?] = 'yes'
order by [Round name]--[Qualified?] DESC, WinLoseRatePerRound DESC

--=================================================--

--4. Crowns I got from solo show (Main show + Trick show)
with cte_SoloCrownRate as(
		select [Show type], f.[Round name], [Round category], [Qualified?]
				, count([Qualified?]) as NumOfFinal
				, sum(count([Qualified?])) over(partition by f.[Round name]) as TotalFinals
		from FGstats as f
		LEFT JOIN Rounds as r
		ON f.[Round name] = r.[Round name]
		where [Round category] = 'Final'
			and [Show type] in ('Main show','Trick show')
		group by [Show type], f.[Round name], [Round category], [Qualified?]
)
select *, cast(NumOfFinal as decimal(5,2))/cast(TotalFinals as decimal(5,2))*100 as WinnigPercentage
from cte_SoloCrownRate
where [Qualified?] = 'yes'

--=================================================--

--5. Crowns I got from team show (Main show + Trick show, not included)

drop view if exists view_TeamPlay 
GO
CREATE view view_TeamPlay as
select [Total rounds played]
		, [Game], [Show type], f.[Round name], [Round type], [Round category]
		, [Qualified?], [Qualified guys], [Rank]
		, [Shards received]
from FGstats as f
LEFT JOIN Rounds as r
ON f.[Round name] = r.[Round name]
where [Show type] not in ('Main show', 'Trick show')
	and [Qualified?] = 'yes'
--group by [Game], f.[Round name], [Round type], [Round category], [Qualified?], [Qualified guys], [Total rounds played]
GO

select *, count(Game) over() as TotalCount
from view_TeamPlay
where [Shards received] >= 20
 --and [Rank] = 1 --when I led to team to 1st place












