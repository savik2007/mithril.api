defmodule Core.Repo.Migrations.RemoveCiEmailDuplicates do
  use Ecto.Migration

  def change do
    execute("""
    UPDATE users
    SET email=substr(email, 1, POSITION('@' in email) + position('.' in SUBSTRING(email, POSITION('@' in email))) - 1) || 'deduplication.' || substr(email, length(email) - (length(email) - (POSITION('@' in email) + position('.' in SUBSTRING(email, POSITION('@' in email))) - 1)) + 1, length(email))
    WHERE id in(
      WITH
        add_0 AS (
          SELECT
            u1.id,
            u1.email,
            u1.password_set_at,
            CASE WHEN json_extract_path_text((u1.priv_settings :: JSON), 'login_hstr') is null OR
                      json_extract_path_text((u1.priv_settings :: JSON), 'login_hstr') ='[]'
                THEN 1 ELSE 0 END AS correct_password,
            lower(u1.email) master_email
          FROM users u1
            JOIN users u2 ON u1.id <> u2.id AND lower(u1.email) = lower(u2.email)
        ),
        add_1 AS (
          SELECT
            a.id,
            a.email,
            a.correct_password,
            a.password_set_at,
            a.master_email,
            max(t.updated_at) max_login,
            count(*) token_qty
          FROM add_0 a LEFT JOIN tokens t ON a.id = t.user_id
          GROUP BY a.id,
            a.email,
            a.correct_password,
            a.password_set_at,
            a.master_email
          ORDER BY master_email
        ),
        add_2 AS (
          SELECT
            a.id,
            a.email,
            a.correct_password,
            a.password_set_at,
            a.master_email,
            max_login,
            token_qty,
            CASE WHEN id='68a47332-c9e2-4b38-a60a-756eed87cd20' THEN 10 ELSE 0 END AS owner,
            CASE WHEN id in('db91eca6-4638-48dc-8649-b2559c7f6410', 'e216ce60-ae87-40a6-885d-38862d7c8c0c') THEN -10 ELSE 0 END AS no_party,
            CASE WHEN password_set_at = max(password_set_at)
            OVER ( PARTITION BY master_email ) THEN 1 ELSE 0 END pair_max_password_set_at,
            CASE WHEN max_login = max(max_login) OVER ( PARTITION BY master_email ) THEN 1 ELSE 0 END pair_max_login,
            CASE WHEN token_qty = max(token_qty) OVER ( PARTITION BY master_email ) THEN 1 ELSE 0 END pair_max_token_qty
          FROM add_1 a
        ),
        add_3 AS (
          SELECT
            id,
            email,
            master_email,
            owner,
            no_party,
            correct_password,
            pair_max_password_set_at,
            pair_max_login,
            pair_max_token_qty,
            correct_password + pair_max_password_set_at + pair_max_login + pair_max_token_qty+owner+no_party as total_score
          FROM add_2
        ),
        final as(
        SELECT
          id,
          email,
          master_email,
          owner,
          no_party,
          correct_password,
          pair_max_password_set_at,
          pair_max_login,
          pair_max_token_qty,
          total_score,
          CASE WHEN total_score=min(total_score) OVER (PARTITION BY master_email) THEN 1 ELSE 0 END to_update
          FROM add_3
        )
        SELECT id FROM final WHERE to_update=1
    )
    """)
  end
end
