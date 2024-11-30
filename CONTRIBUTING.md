### How to build Maccy locally without Apple ID

In XCode: go to Maccy's `Signing & Capabilities` and change `Team` to `None` and Signing Certificate to `Sign to run locally`

Or do the same in `Maccy.xcodeproj/project.pbxproj`:

```
-    DEVELOPMENT_TEAM = MN3X4648SC;
+    DEVELOPMENT_TEAM = "";
```

```
-    "CODE_SIGN_IDENTITY[sdk=macosx*]" = "Apple Development";
+    "CODE_SIGN_IDENTITY[sdk=macosx*]" = "-";
```

Optionally ignore those changes in git:

`git update-index --skip-worktree Maccy.xcodeproj/project.pbxproj`
