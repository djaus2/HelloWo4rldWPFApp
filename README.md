# Simple Hello World for Releases

This is a simple "Hello World" project designed to demonstrate the process of creating and managing releases in a software development workflow. The project includes basic code that outputs "Hello, World!" to the console, along with instructions for building and releasing the application.

## Getting Started

To get started with this project, you'll need to clone the repository and open it in your favorite IDE. Once you have the project set up, you can build and run the application to see the "Hello, World!" output.

## Building the Application

To build the application, use the following command:

```
dotnet build
```

## Running the Application

To run the application, use the following command:

```
dotnet run
```

## Creating a Release

To create a release for the application, follow these steps:

1. The version number is auto=incremented in the form 1.0.nn 
2. Push the changes to the remote repository.
3. Run ```./release.ps1```
4. Also run ```./release.ps1 -DryRun``` to check without creating a new Release
    - The version does get auto-incremented though.
5. There are some scripts for resetting the version.

## Reuse

To use this Release mechanism in another WPF project:
- Copy the release.ps1 script to the new project.
- mdir .GitHub
- mkdir .GitHub/workflows
- copy .github/workflows/release.yml to the new project in that workflows folder
- In that .yml file change the default app name HelloWpfApp to the new app name. Look for:  
```default: 'HelloWpfApp'```
