-- PART I: SCHOOL ANALYSIS
-- 1. View the schools and school details tables
use maven_final_project;

SELECT * FROM schools;
SELECT * FROM school_details;

-- 2. In each decade, how many schools were there that produced players?

WITH schools AS (SELECT		s.playerID, s.schoolID, s.yearID	
							FROM schools s
							LEFT JOIN school_details sd
							ON s.schoolID = sd.schoolID),
				
	numSchools AS (SELECT	COUNT(playerID) AS numPlayers, 
							ROUND(yearID, -1) AS decade, 
							COUNT(DISTINCT schoolID) AS numSchools
							FROM schools
							GROUP BY decade)		
	SELECT * 
	FROM numSchools
	ORDER BY decade;


-- 3. What are the names of the top 5 schools that produced the most players?

SELECT 	sd.name_full, COUNT(DISTINCT playerID) AS totalPlayers
FROM 	schools s 
		LEFT JOIN school_details sd
		ON s.schoolID = sd.schoolID  
GROUP BY sd.name_full
ORDER BY totalPlayers DESC
LIMIT 5;

-- 4. For each decade, what were the names of the top 3 schools per country that produced the most players?

WITH ds AS 	(SELECT ROUND(s.yearID, -1) AS decade, sd.name_full, COUNT(DISTINCT playerID) AS totalPlayers
			FROM 	schools s 
					LEFT JOIN school_details sd
					ON s.schoolID = sd.schoolID  
			GROUP BY decade, sd.schoolID),

	rn 	AS	(SELECT 	decade, name_full, totalPlayers, 
						ROW_NUMBER() OVER(PARTITION BY decade ORDER BY totalPlayers DESC ) AS row_num
						FROM ds)
						
SELECT decade, name_full, totalPLayers FROM rn
WHERE 	row_num <= 3
ORDER BY decade DESC, row_num;

-- PART II: SALARY ANALYSIS
-- 1. View the salaries table

SELECT * FROM salaries;

-- 2. Return the top 20% of teams in terms of average annual spending

-- SELECT yearID, teamID, SUM(salary) AS total_spend FROM salaries
-- GROUP BY yearID, teamID 
-- ORDER BY yearID DESC, teamID, total_spend DESC;

WITH total_spend AS (SELECT yearID, teamID, SUM(salary) AS total_spend 
					FROM salaries
					GROUP BY teamID, yearID
					ORDER BY teamID, yearID),

	spend_pct AS 	(SELECT teamID, AVG(total_spend) AS avg_spend,
					NTILE(5) OVER(ORDER BY AVG(total_spend) DESC ) AS spend_pct
					FROM total_spend
					GROUP BY teamID)

SELECT 	teamID, ROUND(avg_spend / 1000000) AS total_in_mil
FROM 	spend_pct
WHERE spend_pct = 1;


-- 3. For each team, show the cumulative sum of spending over the years
SELECT * FROM salaries;

WITH ts AS (SELECT   teamID, yearID, SUM(salary) AS total_spend
			FROM 	 salaries
			GROUP BY teamID, yearID
			ORDER BY teamID, yearID)

SELECT 	*, 
		ROUND(SUM(total_spend) OVER(PARTITION BY teamID ORDER BY yearID)/1000000, 1) AS cumalative_sum_millions
FROM 	ts;

-- 4. Return the first year that each team's cumulative spending surpassed 1 billion

SELECT * FROM salaries;

WITH ts AS (SELECT   teamID, yearID, SUM(salary) AS total_spend
			FROM 	 salaries
			GROUP BY teamID, yearID
			ORDER BY teamID, yearID),
			
	 cs AS (SELECT 	*, 
			SUM(total_spend) OVER(PARTITION BY teamID ORDER BY yearID) AS cumalative_sum
			FROM 	ts),
			
	 rn AS (SELECT 	teamID, yearID, cumalative_sum,
			ROW_NUMBER() OVER(PARTITION BY teamID ORDER BY cumalative_sum ) AS rn
			FROM 	cs
			WHERE cumalative_sum > 1000000000)
			
SELECT 	teamID, yearID, ROUND(cumalative_sum / 1000000000, 2) AS cumulative_sum_billions
FROM  	rn 
WHERE rn = 1;

-- PART III: PLAYER CAREER ANALYSIS
-- 1. View the players table and find the number of players in the table
SELECT * FROM players;
SELECT COUNT(playeriD) FROM players; -- 18,589

-- 2. For each player, calculate their age at their first game, their last game, and their career length (all in years). Sort from longest career to shortest career.
WITH careerYears AS (SELECT DISTINCT nameGiven, debut, finalGame,
					CAST(CONCAT(birthYear, '-', birthMonth, '-', birthDay) AS DATE)  AS birthDate
					FROM players)
					
SELECT 	*,
		TIMESTAMPDIFF(YEAR, birthDate, debut) AS starting_age,
		TIMESTAMPDIFF(YEAR, birthDate, finalGame ) AS ending_age,
		TIMESTAMPDIFF(YEAR, debut, finalGame ) AS career_length
FROM 	careerYears;

-- 3. What team did each player play on for their starting and ending years?
SELECT * FROM salaries;

SELECT  p.nameGiven, 
		s.yearID AS startingYear, s.teamID AS startingTeam, e.yearID AS endingYear, e.teamID AS endingTeam 
FROM 	players p
		INNER JOIN salaries s
				ON p.playerID = s.playerID
				AND YEAR(p.debut) = s.yearID
		INNER JOIN salaries e
				ON p.playerID = e.playerID
				AND YEAR(p.finalGame) = e.yearID;


-- 4. How many players started and ended on the same team and also played for over a decade?
SELECT  p.nameGiven, 
		s.yearID AS startingYear, s.teamID AS startingTeam, e.yearID AS endingYear, e.teamID AS endingTeam 
FROM 	players p
		INNER JOIN salaries s
				ON p.playerID = s.playerID
				AND YEAR(p.debut) = s.yearID
		INNER JOIN salaries e
				ON p.playerID = e.playerID
				AND YEAR(p.finalGame) = e.yearID
WHERE 	s.teamID = e.teamID AND e.yearID - s.yearID > 10;

-- PART IV: PLAYER COMPARISON ANALYSIS
-- 1. View the players table
SELECT * FROM players;

-- 2. Which players have the same birthday?
WITH bn AS (SELECT 	nameGiven, CAST(CONCAT(birthYear, '-', birthMonth, '-', birthDay) AS DATE) AS birthDate 
			FROM 	players)
			
SELECT 	birthDate, 
		GROUP_CONCAT(nameGiven SEPARATOR ', ') AS players,
		COUNT(nameGiven) AS numPlayers
FROM 	bn
WHERE 	birthDate IS NOT NULL AND YEAR(birthDate) BETWEEN 1980 AND 1990
GROUP BY birthDate
HAVING COUNT(nameGIven) >= 2 
ORDER BY birthDate DESC;


-- 3. Create a summary table that shows for each team, what percent of players bat right, left and both

SELECT p.nameGiven, s.teamID, p.bats 
FROM 	players p 
		INNER JOIN salaries s 
		ON p.playerID = s.playerID;

WITH bat AS (SELECT p.playerID, s.teamID, p.bats 
		 FROM 	players p 
		 		INNER JOIN salaries s 
				ON p.playerID = s.playerID)

-- SELECT 	teamID, COUNT(playerID) AS numPlayers,
-- 		SUM(CASE WHEN bats = 'R' THEN 1 ELSE 0 END) AS batRight,
-- 		SUM(CASE WHEN bats = 'L' THEN 1 ELSE 0 END) AS batLeft,
-- 		SUM(CASE WHEN bats = 'B' THEN 1 ELSE 0 END) AS batBoth
-- FROM 	bat
-- GROUP BY teamID;

SELECT 	teamID, 
		ROUND(SUM(CASE WHEN bats = 'R' THEN 1 ELSE 0 END) / COUNT(playerID) * 100, 1) AS batRight,
		ROUND(SUM(CASE WHEN bats = 'L' THEN 1 ELSE 0 END) / COUNT(playerID) * 100, 1) AS batLeft,
		ROUND(SUM(CASE WHEN bats = 'B' THEN 1 ELSE 0 END) / COUNT(playerID) * 100, 1) AS batBoth
FROM 	bat
GROUP BY teamID;
-- 4. How have average height and weight at debut game changed over the years, and what's the decade-over-decade difference?

WITH hw AS (SELECT  AVG(height) AS avgHeight, 
					AVG(weight) AS avgWeight,
					ROUND(YEAR(debut), -1) AS decade
					FROM 	players
					GROUP BY decade)

SELECT 	decade, 
-- 		avgHeight, avgWeight,
-- 		LAG(avgHeight) OVER(ORDER BY decade) AS heightPrior,
-- 		LAG(avgWeight) OVER(ORDER BY decade) AS weightPrior,
		ROUND(avgHeight - LAG(avgHeight) OVER(ORDER BY decade), 3) AS heightDiff,
		ROUND(avgWeight - LAG(avgWeight) OVER(ORDER BY decade), 3) AS weightDiff
FROM 	hw
WHERE decade IS NOT null;
