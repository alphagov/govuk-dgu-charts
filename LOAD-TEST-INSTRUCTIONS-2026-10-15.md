Load Test Plan - October 15, 2026

Changes Made
Updated gunicorn from 4 workers to 4 workers with 4 threads each.
This gives us 48 concurrent requests total (vs 12 before).

What Changed in the Code
File: charts/app-of-apps/values-staging.yaml line 23

Old: --workers 4
New: --workers 4 --threads 4

Why This Helps
Previous test: 45 VUs hit staging, got 47% errors (queue was full with only 12 concurrent slots)
Now: 48 concurrent slots should handle load much better

Test Plan

Run Stress Test Profile
This test will gradually push load up to see where the new limit is.

Command:
./charts/ndl-load-test/load-test.sh --profile stress

Profile Details:
- Start with 50 VUs
- Ramp up slowly to 100 VUs
- Hold at different levels to see where errors happen
- Total time: about 45 minutes

What to Monitor
1. Watch the k6 logs as test runs
2. Check Grafana dashboard for real-time metrics
3. Look for:
   - Error rate (should be much lower than 47%)
   - Memory usage (should stay under 4 GiB)
   - CPU usage (no issues expected)
   - Pod status (no restarts)

Expected Results
- Error rate should drop significantly from 47% to much lower
- Should handle 50+ VUs without saturation errors
- Memory should stay around 2.5 GiB (threads share memory)

Commands to Run

Start the stress test:
./charts/ndl-load-test/load-test.sh --profile stress

Monitor logs while running:
gds aws govuk-staging-dguengineer -- kubectl logs -n datagovuk -l app=ndl-load-test -f

Check pod status:
gds aws govuk-staging-dguengineer -- kubectl get pod -n datagovuk -l app=ckan

Check Grafana dashboard:
https://grafana.eks.staging.govuk.digital/d/dgu-app-requests/ndl-data-gov-uk

After Test Completes
1. Collect the k6 summary results
2. Compare error rates to baseline test (47%)
3. Document findings
4. Decide if ready for production rollout
