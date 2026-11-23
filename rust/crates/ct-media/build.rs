use std::env;
use std::process::Command;

fn main() {
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if target_os != "macos" {
        return;
    }

    // Garante que binários e testes linkados com ct-media encontrem libswift_Concurrency.dylib
    // no macOS (/usr/lib/swift e toolchain ativa do Xcode).
    println!("cargo:rustc-link-arg=-Wl,-rpath,/usr/lib/swift");

    if let Ok(output) = Command::new("xcode-select").arg("-p").output()
        && output.status.success()
    {
        let xcode_path = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if !xcode_path.is_empty() {
            let swift_lib =
                format!("{xcode_path}/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx");
            println!("cargo:rustc-link-arg=-Wl,-rpath,{swift_lib}");
            println!("cargo:rustc-link-search=native={swift_lib}");

            let swift_55 = format!(
                "{xcode_path}/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-5.5/macosx"
            );
            println!("cargo:rustc-link-arg=-Wl,-rpath,{swift_55}");
            println!("cargo:rustc-link-search=native={swift_55}");
        }
    }
}
