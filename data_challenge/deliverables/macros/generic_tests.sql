{% test unique_combination(model, columns) %}
-- Duplicate groups violate a model's declared composite grain.
select {{ columns }}
from {{ model }}
group by {{ columns }}
having count(*) > 1
{% endtest %}

{% test not_negative(model, column_name) %}
-- Return negative values so dbt reports them as failures.
select {{ column_name }}
from {{ model }}
where {{ column_name }} < 0
{% endtest %}

{% test between_0_and_1(model, column_name) %}
-- Rates outside the inclusive zero-to-one range are invalid.
select {{ column_name }}
from {{ model }}
where {{ column_name }} < 0 or {{ column_name }} > 1
{% endtest %}
