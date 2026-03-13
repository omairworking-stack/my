curl ^"http://183.82.6.147:4622/ERP/AuditAccounts/Analytics/AnalyzeTrialBalance?analysisType=1^" ^
  -H ^"Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJVc2VySWQiOiI4NiIsIlVzZXJHcm91cElkIjoiMSIsIkNvbXBhbnlJZCI6IjEiLCJGaW5hbmNpYWxZZWFySWQiOiI5NCIsIkFwcGxpY2F0aW9uSWQiOiIxIiwiSXNTdXBlclVzZXIiOiJUcnVlIiwiU2Vzc2lvbklkIjoiU2Vzc2lvbl83ZDgzZTZhZi1kYjdkLTQ5MDAtOThlZS03NWFjZTRmOGI1YmEiLCJGaW5ZZWFyU3RhcnREYXRlIjoiMy8xLzIwMjYgMTI6MDA6MDAgQU0iLCJGaW5ZZWFyRW5kRGF0ZSI6IjIvMjgvMjAyNyAxMjowMDowMCBBTSIsInBheXJvbGxNb250aElkIjoiMCIsImh0dHA6Ly9zY2hlbWFzLm1pY3Jvc29mdC5jb20vd3MvMjAwOC8wNi9pZGVudGl0eS9jbGFpbXMvcm9sZSI6IkFkbWluIiwiZXhwIjoxNzczMzc0NjQxLCJpc3MiOiJodHRwOi8vMTAzLjE5NS4yNDYuMjQ2OjgwMTMvIiwiYXVkIjoiaHR0cDovLzEwMy4xOTUuMjQ2LjI0Njo4MDE0LyJ9.XJFByD55c9GAJH2__jj4sGgEWRV06cACMnEMtr-3ASc^" ^
  -H ^"Referer: http://localhost:4200/^" ^
  -H ^"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36^" ^
  -H ^"Accept: application/json, text/plain, */*^" ^
  -H ^"Content-Type: application/json^" ^
  --data-raw ^"^{^\^"companyId^\^":1,^\^"financialYearID^\^":3,^\^"fromDate^\^":^\^"2021-03-01^\^",^\^"toDate^\^":^\^"2022-02-28^\^",^\^"reportType^\^":^\^"TB^\^",^\^"projectionParams^\^":^{^\^"projectionYears^\^":10,^\^"loanAmount^\^":2222,^\^"repaymentPeriod^\^":12,^\^"interestPeriod^\^":122^}^}^"
