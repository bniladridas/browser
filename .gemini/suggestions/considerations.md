# Network Monitoring Feature Considerations

When adding network monitoring to this project, here are some things to keep in mind.

The monitoring should capture accurate timing data even when requests fail. If a request throws an exception, the elapsed time until the failure should still be recorded.

When displaying network events in a dialog or debug screen, consider how the UI handles updates. Local state that gets out of sync with the monitoring service can confuse users.

Queue operations in the monitoring service should be efficient. Using ListQueue instead of List with removeAt(0) can improve performance when events are added frequently.

Duplicate utility functions like string truncation can be consolidated into shared extensions. This makes the codebase easier to maintain and reduces inconsistencies.

Before committing changes, run all pre-commit hooks including flutter analyze and flutter test. Some hooks check commit message format which must follow the repository conventions.

If a suggestion from code review requires multiple commits to apply, consider using the .gemini/suggestions folder to track progress. This helps ensure nothing is missed.

Take time to verify that all related files are updated when making changes. A single refactor may affect multiple parts of the codebase.
