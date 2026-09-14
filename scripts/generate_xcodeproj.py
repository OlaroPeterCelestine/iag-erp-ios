import json
import hashlib
from pathlib import Path

root = Path("/Users/pecelestine/Desktop/iag/finance/erp-ios")
app_files = [
    "App/ErpIOSApp.swift",
    "App/LoginView.swift",
    "App/ShellViews.swift",
    "App/ClockInView.swift",
    "App/RecordViews.swift",
    "App/AccessViews.swift",
]


def uid(name: str) -> str:
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


files = {
    "ErpIOSApp.swift": uid("file-ErpIOSApp"),
    "LoginView.swift": uid("file-LoginView"),
    "ShellViews.swift": uid("file-ShellViews"),
    "ClockInView.swift": uid("file-ClockInView"),
    "RecordViews.swift": uid("file-RecordViews"),
    "AccessViews.swift": uid("file-AccessViews"),
    "Assets": uid("file-Assets"),
}

builds = {k: uid(f"build-{k}") for k in files}
group_app = uid("group-app")
group_products = uid("group-products")
group_main = uid("group-main")
sources = uid("phase-sources")
resources = uid("phase-resources")
frameworks = uid("phase-frameworks")
target = uid("target-app")
config_debug = uid("cfg-debug")
config_release = uid("cfg-release")
config_list_target = uid("cfglist-target")
config_project_debug = uid("cfg-proj-debug")
config_project_release = uid("cfg-proj-release")
config_list_project = uid("cfglist-proj")
project = uid("project")
legacy = uid("legacy")
pkg_ref = uid("pkg-ref")
pkg_product = uid("pkg-product")
pkg_dep = uid("pkg-dep")
product_ref = uid("product-ref")

file_refs = []
build_files = []
children = []
for name, fid in files.items():
    if name == "Assets":
        file_refs.append(
            f'\t\t{fid} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};'
        )
        build_files.append(
            f"\t\t{builds[name]} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* Assets.xcassets */; }};"
        )
        children.append(f"\t\t\t\t{fid} /* Assets.xcassets */,")
    else:
        file_refs.append(
            f'\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = "<group>"; }};'
        )
        build_files.append(
            f"\t\t{builds[name]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};"
        )
        children.append(f"\t\t\t\t{fid} /* {name} */,")

source_phase_files = "\n".join(
    f"\t\t\t\t{builds[n]} /* {n} in Sources */," for n in files if n != "Assets"
)
resource_phase_files = f"\t\t\t\t{builds['Assets']} /* Assets.xcassets in Resources */,"

pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_files)}
		{pkg_dep} /* ErpCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {pkg_product} /* ErpCore */; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{chr(10).join(file_refs)}
		{product_ref} /* ERP iOS.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "ERP iOS.app"; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{pkg_dep} /* ErpCore in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{group_app} /* App */ = {{
			isa = PBXGroup;
			children = (
{chr(10).join(children)}
			);
			path = App;
			sourceTree = "<group>";
		}};
		{group_products} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{product_ref} /* ERP iOS.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
		{group_main} = {{
			isa = PBXGroup;
			children = (
				{group_app} /* App */,
				{group_products} /* Products */,
			);
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target} /* ERP iOS */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {config_list_target} /* Build configuration list for PBXNativeTarget "ERP iOS" */;
			buildPhases = (
				{sources} /* Sources */,
				{frameworks} /* Frameworks */,
				{resources} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = "ERP iOS";
			packageProductDependencies = (
				{pkg_product} /* ErpCore */,
			);
			productName = "ERP iOS";
			productReference = {product_ref} /* ERP iOS.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1600;
				LastUpgradeCheck = 1600;
			}};
			buildConfigurationList = {config_list_project} /* Build configuration list for PBXProject "ErpIOS" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {group_main};
			packageReferences = (
				{pkg_ref} /* XCLocalSwiftPackageReference */,
			);
			productRefGroup = {group_products} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target} /* ERP iOS */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{resource_phase_files}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{source_phase_files}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{config_project_debug} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{config_project_release} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_VERSION = 5.0;
			}};
			name = Release;
		}};
		{config_debug} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = "ERP iOS";
				INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "ERP uses your location to verify you are on an IAG site or block when you clock in.";
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.business";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = africa.iag.erp.ios;
				PRODUCT_NAME = "ERP iOS";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = Debug;
		}};
		{config_release} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = "ERP iOS";
				INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "ERP uses your location to verify you are on an IAG site or block when you clock in.";
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.business";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = africa.iag.erp.ios;
				PRODUCT_NAME = "ERP iOS";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{config_list_project} /* Build configuration list for PBXProject "ErpIOS" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{config_project_debug} /* Debug */,
				{config_project_release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{config_list_target} /* Build configuration list for PBXNativeTarget "ERP iOS" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{config_debug} /* Debug */,
				{config_release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
		{pkg_ref} /* XCLocalSwiftPackageReference */ = {{
			isa = XCLocalSwiftPackageReference;
			relativePath = .;
		}};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		{pkg_product} /* ErpCore */ = {{
			isa = XCSwiftPackageProductDependency;
			productName = ErpCore;
		}};
/* End XCSwiftPackageProductDependency section */
	}};
	rootObject = {project} /* Project object */;
}}
"""

out = root / "ErpIOS.xcodeproj"
out.mkdir(exist_ok=True)
(out / "project.pbxproj").write_text(pbx)
print("wrote", out / "project.pbxproj")
print("target", target)
print("project", project)
