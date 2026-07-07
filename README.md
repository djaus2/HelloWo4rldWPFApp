# Simple Hello World for Releases

This is a simple "Hello World" project designed to demonstrate the process of creating and managing releases in a software development workflow. The project includes basic code that outputs "Hello, World!" to a form, along with instructions for building and releasing the application.

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

> Assumption: The app project folder is one deep in solution folder.  
> As per here:  
```  
SolutionFolder
├─ HelloWo4rldWPFApp.sln
├─ etc ...
├─ HelloWo4rldWPFApp
│  ├─ HelloWo4rldWPFApp.csproj
│  ├─ App.xaml
│  ├─ App.xaml.cs
│  ├─ MainWindow.xaml
│  ├─ MainWindow.xaml.cs
│  └─ etc ...
└─ .github
   └─ workflows
      └─ release.yml
```

To use this Release mechanism in another WPF project:
- Copy the release.ps1 script to the root of the new project.
- In the target root:
  - mkdir .github
  - mkdir .github/workflows
- copy ``.github/workflows/release.yml`` from here to the new project in the workflows folder
- In the target ``release.yml`` file change the default app name ``HelloWo4rldWPFApp`` to the new app name. Look for:  
```
env:
      APP_NAME: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.app_name || 'HelloWo4rldWPFApp' }}
 ```

 ## Future Improvements
 - ~~Pass the app name as a parameter from release.ps1 to the release.yml file so that it can be used in the workflow without needing to edit the workflow file.~~
 - Dispensing withthat idea.
 - That would mean making secrets available.
 - So as is need to be logged into GitHub with the repository credentials, ie can push, for release.ps1 to work.
 - ***Simplest:*** Just change the app name in release.yml
 - Issue though: seems that anyone can currently create a release?? :(
 - 