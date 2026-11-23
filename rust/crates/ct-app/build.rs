use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    println!("cargo:rerun-if-changed=assets/pit.rc");
    println!("cargo:rerun-if-changed=assets/icon.ico");

    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if target_os == "macos" {
        println!("cargo:rustc-link-arg=-Wl,-rpath,/usr/lib/swift");
        if let Ok(output) = Command::new("xcode-select").arg("-p").output()
            && output.status.success()
        {
            let xcode_path = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !xcode_path.is_empty() {
                let swift_lib = format!(
                    "{xcode_path}/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx"
                );
                println!("cargo:rustc-link-arg=-Wl,-rpath,{swift_lib}");
                println!("cargo:rustc-link-search=native={swift_lib}");
            }
        }
        return;
    }
    if target_os != "windows" {
        return;
    }

    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let rc_path = manifest_dir.join("assets").join("pit.rc");
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let res_obj = out_dir.join("pit_icon.o");

    let candidates = [
        "windres",
        "x86_64-w64-mingw32-windres",
        "llvm-windres",
    ];

    for tool in candidates {
        let status = Command::new(tool)
            .arg("-i")
            .arg(&rc_path)
            .arg("-o")
            .arg(&res_obj)
            .arg("-O")
            .arg("coff")
            .arg("--include-dir")
            .arg(manifest_dir.join("assets"))
            .status();

        if let Ok(s) = status && s.success() {
            println!("cargo:rustc-link-arg={}", res_obj.display());
            return;
        }
    }

    println!(
        "cargo:warning=windres não encontrado; executável será compilado sem ícone embutido no .exe"
    );
}
