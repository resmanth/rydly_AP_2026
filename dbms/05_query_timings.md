# CP4 — Query Performance Timings

**Database:** `rydly_cp4`
**PostgreSQL:** 18.6
**Method:** `EXPLAIN (ANALYZE, BUFFERS)`
**Runs per query:** 3
**Unit:** milliseconds (ms)

| Query | Description | Run 1 | Run 2 | Run 3 | Average |
|---:|---|---:|---:|---:|---:|
| 1 | Available cars by city and filters | 0.106 | 0.093 | 0.091 | **0.097** |
| 2 | Date-based car availability | 0.095 | 0.096 | 0.096 | **0.096** |
| 3 | Insert a pending booking | 0.981 | 0.962 | 0.908 | **0.950** |
| 4 | User booking history | 0.100 | 0.112 | 0.094 | **0.102** |
| 5 | Owner dashboard | 0.121 | 0.143 | 0.134 | **0.133** |
| 6 | Update booking status | 0.636 | 0.596 | 0.669 | **0.634** |
| 7 | Top 5 booked categories | 0.128 | 0.107 | 0.118 | **0.118** |
| 8 | City-wise revenue | 0.157 | 0.184 | 0.180 | **0.174** |
| 9 | Toggle car availability | 0.258 | 0.260 | 0.255 | **0.258** |
| 10 | Upcoming confirmed trips | 0.085 | 0.083 | 0.082 | **0.083** |

## Notes

- Each query was executed three times using PostgreSQL EXPLAIN (ANALYZE, BUFFERS).
- Queries 3, 6 and 9 were executed inside transactions and rolled back.
- Before each Q6 run, booking 1 was temporarily set to `pending` inside the transaction.
- Execution plans for all three runs of each query are stored in `dbms/plans/`.
- Execution times are specific to this PostgreSQL instance and test dataset.
