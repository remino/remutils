use anyhow::{Context, Result};
use dotenvy::from_path_iter;
use std::collections::HashMap;
use std::env;
use std::path::Path;

const BUILD_ENV_KEYS: &[&str] = &[
    "LITESITE_BUILD_INCLUDES",
    "LITESITE_BUILD_MINIFY",
    "LITESITE_BUILD_BROTLI",
    "LITESITE_BUILD_GZIP",
    "LITESITE_BUILD_ZSTD",
    "LITESITE_BUILD_AVIF_JPEG",
    "LITESITE_BUILD_AVIF_WEBP",
];

pub fn ensure_site_root(root: &Path) -> Result<()> {
    let mut missing = false;

    for required in ["src", ".deploy-filter", "justfile", ".editorconfig"] {
        if !root.join(required).exists() {
            eprintln!("litesite: expected {}/{}", root.display(), required);
            missing = true;
        }
    }

    if missing {
        std::process::exit(1);
    }

    Ok(())
}

pub fn load_site_env(root: &Path) -> Result<HashMap<String, String>> {
    let mut values: HashMap<String, String> = env::vars().collect();
    let caller_values: HashMap<String, String> = BUILD_ENV_KEYS
        .iter()
        .filter_map(|key| env::var(key).ok().map(|value| ((*key).to_string(), value)))
        .collect();
    let env_file = root.join(".env");

    if env_file.is_file() {
        for item in from_path_iter(&env_file)
            .with_context(|| format!("litesite: cannot read {}", env_file.display()))?
        {
            let (key, value) = item?;
            values.insert(key, value);
        }
    }

    for (key, value) in caller_values {
        values.insert(key, value);
    }

    Ok(values)
}

pub fn env_enabled(values: &HashMap<String, String>, name: &str) -> bool {
    match values
        .get(name)
        .map(|value| value.trim().to_ascii_lowercase())
    {
        None => true,
        Some(value) if value.is_empty() => false,
        Some(value) if matches!(value.as_str(), "0" | "false" | "no" | "off") => false,
        Some(_) => true,
    }
}

pub fn env_enabled_includes(values: &HashMap<String, String>) -> bool {
    values
        .get("LITESITE_BUILD_INCLUDES")
        .map(|_| env_enabled(values, "LITESITE_BUILD_INCLUDES"))
        .unwrap_or(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn falsey_env_values_disable_features() {
        let mut values = HashMap::new();
        for value in ["0", "false", "no", "off", ""] {
            values.insert("FEATURE".to_string(), value.to_string());
            assert!(!env_enabled(&values, "FEATURE"));
        }
    }

    #[test]
    fn truthy_or_missing_env_values_enable_features() {
        let mut values = HashMap::new();
        assert!(env_enabled(&values, "FEATURE"));
        values.insert("FEATURE".to_string(), "1".to_string());
        assert!(env_enabled(&values, "FEATURE"));
    }
}
