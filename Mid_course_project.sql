USE mavenfuzzyfactory;
/* datum zadání: "2012-11-27"
cíle:
- popsat příbeh růstu firmy pomocí trendových výkonnostních dat
- použít databázi k vysvětlení detailů okolo růstu a kvantifikovat dopad některých "našich úspěchů" na tržby
- analyzov aktuální data a použít dostupná data na určení budoucích příležitostí (asi myšleno jako co nefunguje a tak a dalo by se zlepšit)

zadání:
1.	Gsearch seems to be the biggest driver of our business. Could you pull monthly 
trends for gsearch sessions and orders so that we can showcase the growth there? 
2.	Next, it would be great to see a similar monthly trend for Gsearch, but this time splitting out nonbrand 
and brand campaigns separately. I am wondering if brand is picking up at all. If so, this is a good story to tell. 
3.	While we’re on Gsearch, could you dive into nonbrand, and pull monthly sessions and orders split by device type? 
I want to flex our analytical muscles a little and show the board we really know our traffic sources. 
4.	I’m worried that one of our more pessimistic board members may be concerned about the large % of traffic from Gsearch. 
Can you pull monthly trends for Gsearch, alongside monthly trends for each of our other channels?
5.	I’d like to tell the story of our website performance improvements over the course of the first 8 months. 
Could you pull session to order conversion rates, by month? 
6.	For the gsearch lander test, please estimate the revenue that test earned us 
(Hint: Look at the increase in CVR from the test (Jun 19 – Jul 28), and use 
nonbrand sessions and revenue since then to calculate incremental value)
7.	For the landing page test you analyzed previously, it would be great to show a full conversion funnel 
from each of the two pages to orders. You can use the same time period you analyzed last time (Jun 19 – Jul 28).
8.	I’d love for you to quantify the impact of our billing test, as well. Please analyze the lift generated 
from the test (Sep 10 – Nov 10), in terms of revenue per billing page session, and then pull the number 
of billing page sessions for the past month to understand monthly impact.
*/

/*
1.	Gsearch seems to be the biggest driver of our business. Could you pull monthly 
trends for gsearch sessions and orders so that we can showcase the growth there?
Moje úvaha:
- co vlastně je bude zajímat? nejspíš:
	- kolik sessions bylo za měsíc
    - kolik bylo objednávek za měsíc
    - kolik produktů se prodalo za měsíc
    - jaký byl obrat za měsíc
    - jaký byl náklad na zboží za měsíc
    - jaká byla hrubá marže
*/

-- KROK 0: s jakými daty hlavně dělám
SELECT
	website_sessions.website_session_id,
    website_sessions.created_at,
    MONTH(website_sessions.created_at),
    website_sessions.utm_source,
    orders.order_id,
    orders.items_purchased,
    orders.price_usd,
    orders.cogs_usd
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < "2012-11-27"
	AND website_sessions.utm_source = "gsearch";


-- KROK 1: FINAl output přehledu
SELECT
    MONTH(website_sessions.created_at) AS month,
    COUNT(DISTINCT website_sessions.website_session_id) AS number_of_sessions,
    COUNT(DISTINCT orders.order_id) AS number_of_orders,
    SUM(orders.items_purchased) AS number_of_sold_products,
    SUM(orders.price_usd) AS total_revenue,
    SUM(orders.cogs_usd) AS total_cogs,
    (SUM(orders.price_usd)-SUM(orders.cogs_usd))/SUM(orders.price_usd) AS avg_margin,
    AVG(orders.price_usd) AS avg_order_value
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < "2012-11-27"
	AND website_sessions.utm_source = "gsearch"
GROUP BY MONTH(website_sessions.created_at);

/*
2.	Next, it would be great to see a similar monthly trend for Gsearch, but this time splitting out nonbrand 
and brand campaigns separately. I am wondering if brand is picking up at all. If so, this is a good story to tell. 
*/
SELECT
	website_sessions.utm_campaign,
    MONTH(website_sessions.created_at) AS month,
    COUNT(DISTINCT website_sessions.website_session_id) AS number_of_sessions,
    COUNT(DISTINCT orders.order_id) AS number_of_orders
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < "2012-11-27"
	AND website_sessions.utm_source = "gsearch"
GROUP BY 2, 1;
-- tohle by bylo asi lepší předělat tak, ať je utm_campaign (brand X nonbrand) ve sloupcích, ne řádcích
-- alternativní provedení tedy níže
-- tj. chci vědět počet sessions a orders dělený dle měsíců a brand X nonbrand
CREATE TEMPORARY TABLE flagged_sessions
SELECT
	website_sessions.website_session_id,
    MONTH(website_sessions.created_at) AS month_nr,
    website_sessions.utm_campaign,
    orders.order_id,
	CASE WHEN website_sessions.utm_campaign = "nonbrand" AND orders.order_id IS NOT NULL THEN 1 ELSE 0 END AS nonbrand_order,
    CASE WHEN website_sessions.utm_campaign = "brand" AND orders.order_id IS NOT NULL THEN 1 ELSE 0 END AS brand_order,
    CASE WHEN website_sessions.utm_campaign = "nonbrand" THEN 1 ELSE 0 END AS nonbrand_session,
    CASE WHEN website_sessions.utm_campaign = "brand" THEN 1 ELSE 0 END AS brand_session
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < "2012-11-27"
	AND website_sessions.utm_source = "gsearch";
SELECT * FROM flagged_sessions;
-- FINAL OUTPUT
SELECT
	month_nr,
    SUM(nonbrand_order) AS nonbrand_orders,
    SUM(brand_order) AS brand_orders,
    SUM(nonbrand_session) AS nonbrand_sessions,
    SUM(brand_session) AS brand_sessions
FROM flagged_sessions
GROUP BY 1;

/*
3.	While we’re on Gsearch, could you dive into nonbrand, and pull monthly sessions and orders split by device type? 
I want to flex our analytical muscles a little and show the board we really know our traffic sources. 
*/
CREATE TEMPORARY TABLE flagged_sessions1
SELECT
	MONTH(website_sessions.created_at) as month_nr,
    website_sessions.website_session_id,
    website_sessions.created_at,
    website_sessions.utm_source,
    website_sessions.utm_campaign,
    website_sessions.device_type,
    orders.order_id,
    CASE WHEN website_sessions.device_type = "mobile" THEN 1 ELSE 0 END AS mobile_session, 
-- když bych počítal (a neSUMOVAL), tak by se 0 taky počítaly a dělaly nepořádek!
    CASE WHEN website_sessions.device_type = "desktop" THEN 1 ELSE 0 END AS desktop_session,
    CASE WHEN website_sessions.device_type = "mobile" AND orders.order_id IS NOT NULL THEN 1 ELSE 0 END AS mobile_order,
    CASE WHEN website_sessions.device_type = "desktop" AND orders.order_id IS NOT NULL THEN 1 ELSE 0 END AS desktop_order
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < "2012-11-27"
	AND website_sessions.utm_source = "gsearch"
    AND website_sessions.utm_campaign = "nonbrand";
-- FINAL OUTPUT
SELECT
	month_nr,
    SUM(mobile_session) AS mobile_sessions,
    SUM(desktop_session) AS desktop_sessions,
    SUM(mobile_order) AS mobile_orders,
    SUM(desktop_order) AS desktop_orders
FROM flagged_sessions1
GROUP BY 1;

/*
4.	I’m worried that one of our more pessimistic board members may be concerned about the large % of traffic from Gsearch. 
Can you pull monthly trends for Gsearch, alongside monthly trends for each of our other channels?
gsearch, bsearch, socialbook
*/
SELECT
	MONTH(website_sessions.created_at) AS month_nr,
    website_sessions.website_session_id,
    website_sessions.created_at,
    website_sessions.utm_source,
    orders.order_id
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < "2012-11-27";

-- tabulka s missing utm_source
SELECT
	website_session_id,
    http_referer,
    CASE WHEN http_referer LIKE "%gsearch%" THEN 1 ELSE 0 END AS gsearch_session1,
    CASE WHEN http_referer LIKE "%bsearch%" THEN 1 ELSE 0 END AS bsearch_session1
FROM website_sessions
	WHERE utm_source IS NULL
    AND website_sessions.created_at < "2012-11-27";
-- dočasná tabulka z toho
CREATE TEMPORARY TABLE missing_utm_source
SELECT
	website_session_id,
    http_referer,
    CASE WHEN http_referer LIKE "%gsearch%" THEN 1 ELSE 0 END AS gsearch_session1,
    CASE WHEN http_referer LIKE "%bsearch%" THEN 1 ELSE 0 END AS bsearch_session1
FROM website_sessions
	WHERE utm_source IS NULL
    AND website_sessions.created_at < "2012-11-27";
SELECT * FROM missing_utm_source;

-- spojení flagged a missing
CREATE TEMPORARY TABLE flagged_with_missing
SELECT
	flagged_sessions2.month_nr,
    flagged_sessions2.website_session_id,
    flagged_sessions2.order_id,
    flagged_sessions2.utm_source,
    flagged_sessions2.gsearch_session,
    flagged_sessions2.bsearch_session,
    flagged_sessions2.socialbook_session,
    missing_utm_source.gsearch_session1,
    missing_utm_source.bsearch_session1
--    (flagged_sessions2.gsearch_session+missing_utm_source.gsearch_session1) AS gsearch_total
FROM
(
SELECT
	MONTH(website_sessions.created_at) as month_nr,
    website_sessions.website_session_id,
    website_sessions.created_at,
    website_sessions.utm_source,
    website_sessions.utm_campaign,
    website_sessions.device_type,
    website_sessions.http_referer,
    orders.order_id,
    CASE WHEN website_sessions.utm_source = "gsearch" THEN 1 ELSE 0 END AS gsearch_session,
    CASE WHEN website_sessions.utm_source = "bsearch" THEN 1 ELSE 0 END AS bsearch_session,
    CASE WHEN website_sessions.utm_source = "socialbook" THEN 1 ELSE 0 END AS socialbook_session
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < "2012-11-27"
) AS flagged_sessions2
LEFT JOIN missing_utm_source
	ON missing_utm_source.website_session_id = flagged_sessions2.website_session_id;
SELECT * FROM flagged_with_missing;

-- full data    
SELECT
	month_nr,
    website_session_id,
--    utm_source,
    order_id,
--    gsearch_session,
--    bsearch_session,
--    socialbook_session,
 --   gsearch_session1,
 --   bsearch_session1,
    (COALESCE(gsearch_session, 0) + COALESCE(gsearch_session1, 0)) AS gsearch_total,
    (COALESCE(bsearch_session, 0) + COALESCE(bsearch_session1, 0)) AS bsearch_total,
    socialbook_session AS socialbook_total
FROM flagged_with_missing;
-- dočasná tabulka z toho
CREATE TEMPORARY TABLE full_data
SELECT
	month_nr,
    website_session_id,
--    utm_source,
    order_id,
--    gsearch_session,
--    bsearch_session,
--    socialbook_session,
 --   gsearch_session1,
 --   bsearch_session1,
    (COALESCE(gsearch_session, 0) + COALESCE(gsearch_session1, 0)) AS gsearch_total,
    (COALESCE(bsearch_session, 0) + COALESCE(bsearch_session1, 0)) AS bsearch_total,
    socialbook_session AS socialbook_total
FROM flagged_with_missing;
SELECT * FROM full_data;
-- FINAL OUTPUT
SELECT
	month_nr,
    SUM(gsearch_total) AS gsearch_sessions,
    SUM(bsearch_total) AS bsearch_sessions,
    SUM(socialbook_total) AS socialbook_sessions,
	SUM(gsearch_order) AS gsearch_orders,
    SUM(bsearch_order) AS bsearch_orders,
    SUM(socialbook_order) AS socialbook_orders
FROM
(
SELECT
	month_nr,
    website_session_id,
    order_id,
    gsearch_total,
    bsearch_total,
    socialbook_total,
    CASE WHEN gsearch_total = 1 AND order_id IS NOT NULL THEN 1 ELSE 0 END AS gsearch_order,
    CASE WHEN bsearch_total = 1 AND order_id IS NOT NULL THEN 1 ELSE 0 END AS bsearch_order,
    CASE WHEN socialbook_total = 1 AND order_id IS NOT NULL THEN 1 ELSE 0 END AS socialbook_order
FROM full_data
) AS prefinal
GROUP BY 1;
/*tady jsem narazil na svou neznalost kampaní/web marketingu:
- jde o to, že jsem missing utm_source nahradil za daný http referer, ale to ve skutečnosti není kampaň, je to organický search
- když chybí utm source, campaing i http referer, tak to není chyba, ale přímé napsání adresy
- socialbook tam sice byl, ale asi až v pozdějších datech
--> tzn. že stačilo rozdělit na 4 typy sessions: gsearch nebo bsearch paid session (dle utm_source) + organická session (když utm_source není,
ale je http referer) + přímá session (když chybí source i referer) ... a ty pak spočítat stejně, jak jsem to udělal (+ já řešil i objednávky)
*/

/*
5.	I’d like to tell the story of our website performance improvements over the course of the first 8 months. 
Could you pull session to order conversion rates, by month? 
*/
SELECT
	MONTH(website_sessions.created_at) AS month_nr,
 --   website_sessions.website_session_id,
 --   orders.order_id
	COUNT(DISTINCT website_sessions.website_session_id) AS number_of_sessions,
    COUNT(DISTINCT orders.order_id) AS number_of_orders,
	(COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id))*100 AS percentage_cvr_rate
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < "2012-11-27"
GROUP BY 1;

/*
6.	For the gsearch lander test, please estimate the revenue that test earned us 
(Hint: Look at the increase in CVR from the test (Jun 19 – Jul 28), and use 
nonbrand sessions and revenue since then to calculate incremental value)
moje úvaha: první pageview na lander-1 byla 2012-06-19 s page_view_id 23504 a session_id 11683
*/
SELECT
	MONTH(website_sessions.created_at) AS month_nr,
    website_sessions.website_session_id,
    website_sessions.created_at,
	website_sessions.utm_source,
    website_sessions.utm_campaign,
    orders.order_id,
    orders.price_usd
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < "2012-11-27"
	AND website_sessions.utm_source = "gsearch"
    AND website_sessions.utm_campaign = "nonbrand";
    
-- dočasná tabulka jakou lander page viděli dané sessions_id
CREATE TEMPORARY TABLE landing_page_version_seen
SELECT
	pageview_id_to_session_id.website_session_id,
    pageview_id_to_session_id.first_pageview_id_seen,
    website_pageviews.pageview_url,
    CASE WHEN website_pageviews.pageview_url = "/home" THEN 1 ELSE 0 END AS home_session,
    CASE WHEN website_pageviews.pageview_url = "/lander-1" THEN 1 ELSE 0 END AS lander_session
FROM
(
SELECT
    website_sessions.website_session_id,
	MIN(website_pageviews.website_pageview_id) AS first_pageview_id_seen
FROM website_sessions
	LEFT JOIN website_pageviews
		ON website_sessions.website_session_id = website_pageviews.website_session_id
WHERE website_sessions.created_at < "2012-11-27"
	AND website_sessions.utm_source = "gsearch"
    AND website_sessions.utm_campaign = "nonbrand"
GROUP BY 1
ORDER BY 1
) AS pageview_id_to_session_id
LEFT JOIN website_pageviews
	ON pageview_id_to_session_id.first_pageview_id_seen = website_pageviews.website_pageview_id;
SELECT * FROM landing_page_version_seen;

-- dočasná tabulka pro první den v daném týdnu
CREATE TEMPORARY TABLE min_week_day
SELECT
    WEEK(website_sessions.created_at) AS week_nr,
    MIN(DATE(website_sessions.created_at)) AS week_start_date
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
WHERE website_sessions.created_at < "2012-11-27"
	AND website_sessions.utm_source = "gsearch"
GROUP BY 1;
SELECT * FROM min_week_day;

-- přehledová tabulka dat pro další práci
SELECT
	MONTH(website_sessions.created_at) AS month_nr,
    WEEK(website_sessions.created_at) AS week_nr,
    min_week_day.week_start_date,
    website_sessions.website_session_id,
    website_sessions.created_at,
	website_sessions.utm_source,
    website_sessions.utm_campaign,
    landing_page_version_seen.pageview_url AS first_page_seen,
    landing_page_version_seen.home_session,
    landing_page_version_seen.lander_session,
    orders.order_id,
    orders.price_usd
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
	LEFT JOIN landing_page_version_seen
		ON landing_page_version_seen.website_session_id = website_sessions.website_session_id
	LEFT JOIN min_week_day
		ON min_week_day.week_nr = WEEK(website_sessions.created_at)
WHERE website_sessions.created_at < "2012-11-27"
	AND website_sessions.utm_source = "gsearch"
    AND website_sessions.utm_campaign = "nonbrand";
    
-- preFINAL output: conversion rates, sessions a revenue před (do vč. 2012-06-18), mezi (mezi 2012-06-19 a 2012-07-28) a po (od vč. 2012-07-29) testu
CREATE TEMPORARY TABLE conso_data
SELECT
	MONTH(website_sessions.created_at) AS month_nr,
    WEEK(website_sessions.created_at) AS week_nr,
    min_week_day.week_start_date,
    website_sessions.website_session_id,
    website_sessions.created_at,
    CASE 
		WHEN website_sessions.created_at < "2012-06-19" THEN "before_test"
        WHEN website_sessions.created_at BETWEEN "2012-06-19" AND "2012-07-29" THEN "during_test"
        WHEN website_sessions.created_at >= "2012-07-29" THEN "after_test"
        ELSE "oops, wrong!" END AS when_created,
	website_sessions.utm_source,
    website_sessions.utm_campaign,
    landing_page_version_seen.pageview_url AS first_page_seen,
    landing_page_version_seen.home_session,
    landing_page_version_seen.lander_session,
    orders.order_id,
    orders.price_usd
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
	LEFT JOIN landing_page_version_seen
		ON landing_page_version_seen.website_session_id = website_sessions.website_session_id
	LEFT JOIN min_week_day
		ON min_week_day.week_nr = WEEK(website_sessions.created_at)
WHERE website_sessions.created_at < "2012-11-27"
	AND website_sessions.utm_source = "gsearch"
    AND website_sessions.utm_campaign = "nonbrand";
SELECT * FROM conso_data;
SELECT
	when_created,
    COUNT(DISTINCT website_session_id) AS sessions_total,
    COUNT(DISTINCT order_id) AS orders_total,
    (COUNT(DISTINCT order_id)/COUNT(DISTINCT website_session_id))*100 AS cvr_rate_in_percentage,
    SUM(price_usd)/COUNT(DISTINCT website_session_id) AS avg_revenue_per_session,
    SUM(price_usd) AS revenue_total
FROM conso_data
GROUP BY 1
ORDER BY 1 DESC;
/* --> zvýšení % earned revenue skrze test 1-(4,0545/2,866) je cca 41,46% 
- oproti kurzovému řešení jsem na to šel jinak: oni řešili rozdíly cvr_rates během testu (to mi nedává tolik smysl,
protože tam je mix obou, takže horší výpovědní hodnota) a po testu a pak to násobili počtem sessions po testu
- já řešil víc před a po testu v relativních číslech: o ccě těch 40 % vyšší cvr_rate a o 20 % vyšší průměrná tržba na session
*/


/*
7.  For the landing page test you analyzed previously, it would be great to show a full conversion funnel 
from each of the two pages to orders. You can use the same time period you analyzed last time (Jun 19 – Jul 28).
postup funnelem: /lander-1 nebo /home --> /products --> /the-original-mr-fuzzy --> /cart --> /shipping --> /billing --> /thank-you-for-your-order
*/

-- kterou landing page (lander-1 nebo home) viděli jako první
CREATE TEMPORARY TABLE first_pageview
SELECT
    website_sessions.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS first_pageview_id
FROM website_sessions
	LEFT JOIN website_pageviews
		ON website_pageviews.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at BETWEEN "2012-06-19" AND "2012-07-28"
GROUP BY 1;
SELECT * FROm first_pageview;

CREATE TEMPORARY TABLE actual_first_pageview
SELECT
	first_pageview.website_session_id,
    first_pageview.first_pageview_id,
    website_pageviews.pageview_url
FROM first_pageview
	LEFT JOIN website_pageviews
		ON website_pageviews.website_pageview_id = first_pageview.first_pageview_id;
SELECT * FROM actual_first_pageview;

CREATE TEMPORARY TABLE flagged_sessions2
SELECT
    website_sessions.website_session_id,
    actual_first_pageview.pageview_url AS first_page_seen,
    website_pageviews.website_pageview_id,
	website_pageviews.pageview_url,
    website_sessions.created_at,
    orders.order_id,
    CASE WHEN website_pageviews.pageview_url IN ("/lander-1", "/home") THEN 1 ELSE 0 END AS homepage_view,
    CASE WHEN website_pageviews.pageview_url = "/products" THEN 1 ELSE 0 END AS products_view,
/* opět POZOR: naštěstí jsem SUMoval, ale když bych COUNToval, tak 0 by dělaly problém!!! */
    CASE WHEN website_pageviews.pageview_url = "/the-original-mr-fuzzy" THEN 1 ELSE 0 END AS mrfuzzy_view,
    CASE WHEN website_pageviews.pageview_url = "/cart" THEN 1 ELSE 0 END AS cart_view,
    CASE WHEN website_pageviews.pageview_url = "/shipping" THEN 1 ELSE 0 END AS shipping_view,
    CASE WHEN website_pageviews.pageview_url = "/billing" THEN 1 ELSE 0 END AS billing_view,
    CASE WHEN website_pageviews.pageview_url = "/thank-you-for-your-order" THEN 1 ELSE 0 END AS thank_you_view
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
	LEFT JOIN website_pageviews
		ON website_pageviews.website_session_id = website_sessions.website_session_id
	LEFT JOIN actual_first_pageview
		ON actual_first_pageview.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at BETWEEN "2012-06-19" AND "2012-07-28";
SELECT * FROM flagged_sessions2;

SELECT
	first_page_seen,
    SUM(homepage_view) AS total_homepage_views,
    SUM(products_view) AS total_products_pageviews,
    SUM(mrfuzzy_view) AS total_mrfuzzy_pageviews,
    SUM(cart_view) AS total_cart_pageviews,
    SUM(shipping_view) AS total_shipping_pageviews,
    SUM(billing_view) AS total_billing_pageviews,
    SUM(thank_you_view) AS total_thank_you_ageviews
FROM flagged_sessions2
GROUP BY 1;

-- FINAL OUTPUT
SELECT
	first_page_seen,
    SUM(products_view)/SUM(homepage_view) AS clicked_to_products,
    SUM(mrfuzzy_view)/SUM(products_view) AS clicked_to_mr_fuzzy,
	SUM(cart_view)/SUM(mrfuzzy_view) AS clicked_to_cart,
    SUM(shipping_view)/SUM(cart_view) AS clicked_to_shipping,
    SUM(billing_view)/SUM(shipping_view) AS clicked_to_billing,
    SUM(thank_you_view)/SUM(billing_view) AS clicked_to_finish_order
FROM flagged_sessions2
GROUP BY 1;


/*
8.	I’d love for you to quantify the impact of our billing test, as well. Please analyze the lift generated 
from the test (Sep 10 – Nov 10), in terms of revenue per billing page session, and then pull the number 
of billing page sessions for the past month to understand monthly impact.
2012-09-10
2012-10-11
moje úvaha o postupu: 
- počet billing pages je easy, to je vpoho
- revenue per billing page bych udělal jako trojí: revenue/billing page (původní), revnue/billing page (billing-2) revenue/billing page (celkově)
- takže budu muset ke každé objednávce dotáhnout, která billing page to byla (původní X testovací)
- nechám si u toho data (asi jako týdny), abych mohl vidět růst
- takže sloupce by měly být něco jako: začátek daného týdne - číslo týdne - revenue/první billing page - revenue/druhá billing page - revenue/všechny verze
*/
   
-- kterou verzi billing page daná session viděla
CREATE TEMPORARY TABLE billing_version
SELECT
	pageview_url,
    website_session_id
FROM website_pageviews
	WHERE created_at < "2012-11-27"
    AND pageview_url IN ("/billing", "/billing-2");
SELECT * FROM billing_version;

-- první den daného týdne
CREATE TEMPORARY TABLE first_day_of_week
SELECT
	WEEK(created_at) AS week_nr,
    MIN(DATE(created_at)) AS first_day_of_week
FROM website_sessions
GROUP BY 1;
SELECT * FROM first_day_of_week;

CREATE TEMPORARY TABLE meta_data
SELECT
	MONTH(website_sessions.created_at) AS month_nr,
    WEEK(website_sessions.created_at) AS week_nr,
    website_sessions.created_at,
    CASE WHEN website_sessions.created_at < "2012-09-10" THEN "before_test" ELSE "after_test" END AS when_billed,
    website_sessions.website_session_id,
    orders.order_id,
    orders.price_usd,
    billing_version.pageview_url AS billing_page_version,
    CASE WHEN billing_version.pageview_url = "/billing" THEN 1 ELSE NULL END AS billing_v1,
/* tady POZOR, měl jsem původně ... ELSE 0 END ..., takže pak když jsem počítal ty hodnoty, tak 0 se počítaly taky
--> počet billing_page verzí se neliš a byly tam i nuly... ale přišel jsem to. joooooo!*/
	CASE WHEN billing_version.pageview_url = "/billing-2" THEN 1 ELSE NULL END AS billing_v2,
    CASE WHEN billing_version.pageview_url = "/billing" THEN price_usd ELSE NULL END AS billing_1_revenue,
    CASE WHEN billing_version.pageview_url = "/billing-2" THEN price_usd ELSE NULL END AS billing_2_revenue
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
	LEFT JOIN billing_version
		ON billing_version.website_session_id = website_sessions.website_session_id
WHERE website_sessions.created_at < "2012-11-27";
SELECT * FROM meta_data;
-- DROP TABLE meta_data;

-- FINAL OUTPUT 1: revenue per billing page version + revenue per billing page total dle týdnů
SELECT
	meta_data.week_nr,
    first_day_of_week.first_day_of_week,
    SUM(billing_1_revenue)/COUNT(billing_v1) AS revenue_per_billing1_session,
    SUM(billing_2_revenue)/COUNT(billing_v2) AS revenue_per_billing2_session,
    (SUM(billing_1_revenue)+SUM(billing_2_revenue))/(COUNT(billing_v1)+COUNT(billing_v2)) AS revenue_per_billing_total
FROM meta_data
	LEFT JOIN first_day_of_week
		ON first_day_of_week.week_nr = meta_data.week_nr
GROUP BY 1, 2
ORDER BY 1;

-- FINAL OUTPUT v1.1: revenue per billing page version + revenue per billing page total dle toho jestli před nebo po testu nové verze
SELECT
	when_billed,
	SUM(price_usd)/COUNT(billing_page_version) AS revenue_per_billing_page_sessions
FROM meta_data
GROUP BY 1;
-- kurz na to šel zase jinak: srovnával revenue/billing page (dle verzí) BĚHEM testu a tam byl rozdíl cca 2násobný

-- FINAL OUTPUT 2: počet billing page sessions dle měsíců a verze billing page + total
SELECT
	month_nr,
    COUNT(billing_v1) AS number_of_billing1_sessions,
    COUNT(billing_v2) AS number_of_billing2_sessions,
	COUNT(billing_page_version) AS number_of_total_billing_sessions
FROM meta_data
GROUP BY 1;
/* tady se taky kurz liší: prostě vzali počet billing sessions za poslední měsíc a vynásobili rozdílem z minulého tasku
za mě to ale nedává smysl, když očividně live byly pořád obě verze stránek, takže jestli, tak aspoň násobit jen s druhou verzí, ne? */