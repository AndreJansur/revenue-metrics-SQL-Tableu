WITH user_monthly AS (
    SELECT
         user_id
        ,date_trunc('month', f.payment_date) AS payment_month
        ,sum(f.revenue_amount_usd) AS monthly_revenue
    FROM project.games_payments AS f
    GROUP BY user_id, date_trunc('month', f.payment_date)
),

user_monthly_w AS (
    SELECT
         *
        ,lead(payment_month) OVER (PARTITION BY user_id ORDER BY payment_month) AS next_payment_month
        ,lag(payment_month) OVER (PARTITION BY user_id ORDER BY payment_month) AS prev_payment_month
        ,lag(monthly_revenue) OVER (PARTITION BY user_id ORDER BY payment_month) AS prev_revenue
    FROM user_monthly
),

metrics_per_user AS (
    SELECT
         *
        ,case
             when next_payment_month IS NULL
                  or next_payment_month > payment_month + interval '1 month' then 1
             else 0
         end AS churned_users_flag
        ,case
             when monthly_revenue > prev_revenue
                  then monthly_revenue - prev_revenue
             else 0
         end AS expansion_mrr
        ,case 
             when monthly_revenue < prev_revenue
                  then prev_revenue - monthly_revenue
             else 0
         end AS contraction_mrr
        ,case
             when next_payment_month IS NULL
                  or next_payment_month > payment_month + interval '1 month'
                  then monthly_revenue
             else 0
         end AS churned_revenue
        ,case
             when prev_payment_month IS NULL
                  then monthly_revenue
             else 0
         end AS new_mrr
    FROM user_monthly_w
)

SELECT
     payment_month
    ,count(distinct user_id) AS paid_users
    ,count(distinct case
          when prev_payment_month IS NULL then user_id
     end) AS new_paid_users
    ,sum(monthly_revenue) AS mrr
    ,sum(new_mrr) AS new_mrr
    ,sum(expansion_mrr) AS expansion_mrr
    ,sum(contraction_mrr) AS contraction_mrr
    ,sum(churned_revenue) AS churned_revenue
    ,sum(churned_users_flag) AS churned_users
FROM metrics_per_user
GROUP BY payment_month
ORDER BY payment_month;
