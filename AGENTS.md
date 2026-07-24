The project you're working on is my dotfiles, which is a chezmoi-managed collection of configuration files and scripts that help set up and maintain my development environment on MacOS.

**Code Style and Structure**
- Write clean, maintainable and technically accurate code.
- All shell scripts must be compatible with Zsh on MacOS.
- Never use an approach you're not confident about. If you're unsure about something, ask for clarity.
- Always follow best practices for Zsh and MacOS system configuration.
- This project should work on MacOS with minimal dependencies.

**Chezmoi Guidelines**
- NEVER change the ~/.config directory or its contents directly. All changes must be made in the chezmoi source directory.
- Never run chezmoi's `apply` unless you are asked to do so.
- Follow chezmoi naming conventions (e.g., `dot_` prefix for dotfiles, `run_` for scripts, `executable_` for executables).
- Use chezmoi templates when configuration needs to vary across machines.
- Use the skill /find-docs if you need help with chezmoi templates or configuration.

This project is open source and the code is available on GitHub, so be sure to follow best practices to make it easy for others to understand, modify, and contribute to the project.
