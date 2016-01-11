# Go App Engine Deploy

A step that deploys Go applications to Google App Engine. This step depends on `michilu/box-goapp`.

## Options

### required

* `token` - The OAuth 2.0 refresh token of the Google account to use for deployment.

## Example

```
box: michilu/goapp
deploy:
  steps:
  - michilu/go-appengine-deploy:
      token:    $APP_ENGINE_TOKEN
```
