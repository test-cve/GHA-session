# GHA-session

GHA concepts:

1. Workflow
2. Jobs - Sequential vs Parallel Jobs
3. Runners -  Provided runners, self hosted runners, docker image as runner, docker image + docker image in step
4. Steps - Actions, Event Activity, Filters
5. Triggers - One, more than one, more than one with diff branches
6. Contexts - 
7. Inputs
8. Secrets and Env Vars
9. Outputs - Artifacts
10. Dependency Caching
11. Expressions, Methods and Conditional Jobs
12. 2 Examples


**Repository Dispatch** - This has to be on Main branch only and will not work for other branches.
<br> **When using workflow_run**: There can only be three levels of nesting i.e. if Workflow A depends on Workflow B and Workflow B on Workflow C, then it will work but not if Workflow D is also there as a dependency.

### Others
Commit messages relevance - [skip ci] , [ci skip] , [skip actions], [actions skip], [no ci]

## About Example:
This is a simple web service with 2 endpoints:

## Endpoints
### Greet Endpoint:
- URL: `/hello/<name>`
- Method: GET
- Description: Returns a greeting message with the provided name.
- Example: `/hello/Prateek` returns `"Hello, Prateek!"`

### Health Check Endpoint:
- URL: `/health`
- Method: GET
- Description: Checks the health of the service and returns status information.
- Example Response:
  ```json
  {
    "status": "Healthy",
    "message": "The service is up and running!",
    "uptime": {
      "days": 0,
      "hours": 1,
      "minutes": 23,
      "seconds": 45
    }
  }
  ```
