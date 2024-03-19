curl -X POST "http://localhost:4566/restapis/ox4i85wh74/prod/_user_request_/createtask" -H 'Content-Type: application/json' -d'
{
  "task_name": "a",
  "cron_expression": "* * * * *"
}'

curl -X POST "http://localhost:4566/restapis/ox4i85wh74/prod/_user_request_/createtask" -H 'Content-Type: application/json' -d'
{
  "task_name": "b",
  "cron_expression": "* * * * *"
}'

curl -X POST "http://localhost:4566/restapis/ox4i85wh74/prod/_user_request_/createtask" -H 'Content-Type: application/json' -d'
{
  "task_name": "c",
  "cron_expression": "* * * * *"
}'

curl -X POST "http://localhost:4566/restapis/ox4i85wh74/prod/_user_request_/createtask" -H 'Content-Type: application/json' -d'
{
  "task_name": "d",
  "cron_expression": "* * * * *"
}'

curl -X POST "http://localhost:4566/restapis/ox4i85wh74/prod/_user_request_/createtask" -H 'Content-Type: application/json' -d'
{
  "task_name": "e",
  "cron_expression": "* * * * *"
}'

curl -X POST "http://localhost:4566/restapis/ox4i85wh74/prod/_user_request_/createtask" -H 'Content-Type: application/json' -d'
{
  "task_name": "f",
  "cron_expression": "* * * * *"
}'

curl -X GET "http://localhost:4566/restapis/ox4i85wh74/prod/_user_request_/listtask" 
echo ""
awslocal s3 ls s3://taskstorage