# Diagnostic Tool Usage Rules (MANDATORY)

## Exhaust All Tools Before Asking the Human

You have access to the entire development environment. Use it.

## Diagnostic Checklist (Complete ALL applicable steps)

### For test failures:
□ Read EXACT error message + full stack trace
□ Read the failing test code completely
□ Read the code under test completely
□ Run the test in isolation with verbose output:
  - Jest: `npx jest <file> -t "<test name>" --verbose`
  - Playwright: `npx playwright test <file> --reporter=list`
  - pytest: `python -m pytest <file>::<test> -v --tb=long`
□ Check git log for recent changes: `git log --oneline -10 -- <test_file> <source_file>`
□ Check .env.test for correct credentials
□ Verify services running: `docker ps`, `lsof -i :3000`, `lsof -i :8000`

### For application bugs:
□ Application logs: `tail -100 logs/*.log`, `docker logs <container> --tail=100`
□ Database state: query via MCP server, psql, or mongosh
□ Configuration: read .env, .env.local, next.config.*, docker-compose.yml
□ Health checks: `curl -v http://localhost:3000/api/health`
□ Recent changes: `git log --oneline -20`, `git diff HEAD~5`
□ Process status: `docker ps`, `ps aux | grep node`, `ps aux | grep python`

### For auth/session issues:
□ Verify credentials from .env.test match what you sent
□ Check token expiry: decode JWT if available
□ Verify auth service is running and accepting connections
□ Query database for test user record
□ Test with curl to isolate client vs server: `curl -X POST <auth_endpoint> -d '{"email":"...","password":"..."}'`
□ Check MSW handlers if running in test mode

### For E2E / Playwright issues:
□ Check if data-testid attributes exist in current DOM
□ Verify page.route() intercepts match current API routes
□ Check if component renders the expected elements (use Playwright trace)
□ Run with `--debug` flag: `npx playwright test <file> --debug`
□ Check screenshots/traces in test-results/ directory

### For data discrepancies:
□ Query database directly for relevant records
□ Compare expected vs actual with specific field values
□ Check for recent migrations: `git log --oneline -- **/migrations/**`
□ Look for data transformation or serialization logic
□ Check caching layers (Redis, in-memory, browser cache)

## Escalation Format

Ask the human ONLY after completing all applicable steps. Use this format:

```
I need help with [specific question].

I have already:
1. [diagnostic step] → [result]
2. [diagnostic step] → [result]
3. [diagnostic step] → [result]

I cannot determine [X] because [reason — tool limitation, access issue, etc.]
```

## NEVER Acceptable

- "Can you check the console?" → YOU check the logs
- "Can you verify the database?" → YOU query it
- "Can you run the tests?" → YOU run them
- "You may want to look at..." → YOU look first
- "The error might be in..." → YOU read the file and confirm
