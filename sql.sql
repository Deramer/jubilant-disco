WITH twenty_tasks_time_diff AS (
    SELECT st_id as student_id, 
        timest - lag(timest, 20) OVER (PARTITION BY st_id ORDER BY timest ASC) AS time_diff
    FROM peas
    WHERE correct = TRUE
        AND timest > '2020-03-01'
        AND timest < '2020-04-01'
 )
 SELECT distinct student_id
 FROM twenty_tasks_time_diff
 WHERE time_diff < '1 hour'::interval;
 
 /* remarks
 	cte в постгресе до 12-ого материализовывал подзапрос и 
    не давал планировщику оптимизировать запрос целиком;
    с целью увеличения производительности стоит запихнуть
    with в подзапрос, но читаемость с with лучше.
    по оптимальности -- лучше встроенных средств языка не будет,
    общая сложность будет ограничена сверху max(N, N_{true} log N_{true}),
    где N -- число записей в таблице, N_{true} -- число строк с 
    correct = True. Я на сях асимптотику лучше не сделаю, хотя
    с константой можно было бы поиграть
*/

WITH active_students AS (
    SELECT st_id as student_id, bool_or(subject = 'math') as math_user
    FROM peas
    GROUP BY st_id
 )
SELECT sum(ch.money) / count(distinct st.st_id) as arpu,
	sum(ch.money) FILTER (WHERE act.student_id IS NOT NULL) / 
    	count(distinct st.st_id) FILTER (WHERE act.student_id IS NOT NULL) as arpau,
   	count(distinct st.st_id) FILTER (WHERE ch.money IS NOT NULL) / count(distinct st.st_id) AS cr,
    count(distinct st.st_id) FILTER (WHERE ch.money IS NOT NULL AND act.student_id IS NOT NULL) / 
    	count(distinct st.st_id) FILTER (WHERE act.student_id IS NOT NULL) as cr_active,
    count(distinct st.st_id) FILTER (WHERE act.math_user and ch.money IS NOT NULL) / 
    	count(distinct st.st_id) FILTER (WHERE act.math_user) as cr_math
FROM studs st
LEFT JOIN checks ch USING (st_id)
LEFT JOIN active_students act ON st.st_id = act.student_id
GROUP BY test_grp;

/* remarks
	"В одном запросе" -- понятие относительное. Я почти уверен, что
    этот запрос не написать чисто в одном запросе (без подзапросов, 
    временных таблиц, вызова процедур, cte...), но я постарался 
    максимально сократить число таких штук.
    Но я б сильно не советовал в проде таким заниматься, чревато ошибками.
    Заметка про cte с прошлого раза верна и здесь.
    Определение "активности" спрашивал у Саши, сошлись на "решал хоть что-то
    хоть когда-то, но не обязательно решил". На собес сойдёт, в жизни вряд ли.
    Аналогично "занимался математикой" и "решил купить матан" связаны только
    если между ними прошло не так много времени, но здесь это никого
    не интересует.
*/
