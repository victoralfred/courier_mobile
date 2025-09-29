# Android Configuration

## Setting up gradle.properties

The `gradle.properties` file contains sensitive information (keystore passwords) and is **NOT** committed to Git.

### Setup Instructions:

1. Copy the template file:
   ```bash
   cp gradle.properties.template gradle.properties
   ```

2. Edit `gradle.properties` and replace the placeholders with your actual values:
   - `APP_UPLOAD_STORE_FILE`: Path to your keystore file
   - `APP_UPLOAD_KEY_ALIAS`: Your key alias
   - `APP_UPLOAD_STORE_PASSWORD`: Your keystore password
   - `APP_UPLOAD_KEY_PASSWORD`: Your key password

3. **IMPORTANT**: Never commit `gradle.properties` to Git. It's already in `.gitignore`.

### Security Note:

If you need to share configurations with team members, use a secure method like:
- Password managers (1Password, LastPass)
- Encrypted environment variables
- Secure CI/CD secrets management

## Keystore File Location

The keystore file should be stored securely and **never** committed to version control.
Current expected location: `/home/voseghale/projects/keys/courier/prod-courier.jks`