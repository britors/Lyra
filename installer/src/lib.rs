//! Domain model shared by the installer UI and the future privileged backend.

/// Values collected by the unprivileged graphical wizard.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InstallConfig {
    pub locale: String,
    pub hostname: String,
    pub full_name: String,
    pub username: String,
    pub password: String,
}

impl Default for InstallConfig {
    fn default() -> Self {
        Self {
            locale: "pt_BR.UTF-8".into(),
            hostname: "lyra-os".into(),
            full_name: String::new(),
            username: String::new(),
            password: String::new(),
        }
    }
}

impl InstallConfig {
    /// Validate user-controlled values before they cross the privilege boundary.
    pub fn validate(&self) -> Result<(), Vec<&'static str>> {
        let mut errors = Vec::new();

        if !matches!(self.locale.as_str(), "pt_BR.UTF-8" | "en_US.UTF-8") {
            errors.push("idioma não suportado");
        }
        if !valid_hostname(&self.hostname) {
            errors.push("nome do dispositivo inválido");
        }
        if self.full_name.trim().is_empty() {
            errors.push("nome completo obrigatório");
        }
        if !valid_username(&self.username) {
            errors.push("nome de usuário inválido");
        }
        if self.password.chars().count() < 8 {
            errors.push("a senha deve ter ao menos 8 caracteres");
        }

        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }
}

fn valid_hostname(value: &str) -> bool {
    let bytes = value.as_bytes();
    !bytes.is_empty()
        && bytes.len() <= 63
        && bytes.first().is_some_and(u8::is_ascii_alphanumeric)
        && bytes.last().is_some_and(u8::is_ascii_alphanumeric)
        && bytes
            .iter()
            .all(|byte| byte.is_ascii_alphanumeric() || *byte == b'-')
}

fn valid_username(value: &str) -> bool {
    let mut chars = value.chars();
    chars.next().is_some_and(|first| first.is_ascii_lowercase())
        && value.len() <= 32
        && value != "root"
        && chars.all(|character| {
            character.is_ascii_lowercase()
                || character.is_ascii_digit()
                || character == '-'
                || character == '_'
        })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn valid_config() -> InstallConfig {
        InstallConfig {
            full_name: "Lyra User".into(),
            username: "lyra".into(),
            password: "harmonia-2026".into(),
            ..InstallConfig::default()
        }
    }

    #[test]
    fn defaults_follow_product_specification() {
        let config = InstallConfig::default();
        assert_eq!(config.locale, "pt_BR.UTF-8");
        assert_eq!(config.hostname, "lyra-os");
    }

    #[test]
    fn accepts_a_complete_configuration() {
        assert_eq!(valid_config().validate(), Ok(()));
    }

    #[test]
    fn rejects_root_and_shell_metacharacters() {
        let mut config = valid_config();
        config.username = "root".into();
        config.hostname = "lyra; reboot".into();

        let errors = config.validate().unwrap_err();
        assert!(errors.contains(&"nome de usuário inválido"));
        assert!(errors.contains(&"nome do dispositivo inválido"));
    }

    #[test]
    fn rejects_incomplete_identity() {
        let errors = InstallConfig::default().validate().unwrap_err();
        assert!(errors.contains(&"nome completo obrigatório"));
        assert!(errors.contains(&"nome de usuário inválido"));
        assert!(errors.contains(&"a senha deve ter ao menos 8 caracteres"));
    }
}
