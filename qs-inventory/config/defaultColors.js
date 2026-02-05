//──────────────────────────────────────────────────────────────────────────────
//  Quasar Store · Configuration Guidelines
//──────────────────────────────────────────────────────────────────────────────
//  This configuration file defines all adjustable parameters for the script.
//  Comments are standardized to help you identify which sections you can safely edit.
//
//  • [EDIT] – Safe for users to modify. Adjust these values as needed.
//  • [INFO] – Informational note describing what the variable or block does.
//  • [ADV]  – Advanced settings. Change only if you understand the logic behind it.
//  • [CORE] – Core functionality. Do not modify unless you are a developer.
//  • [AUTO] – Automatically handled by the system. Never edit manually.
//
//  Always make a backup before editing configuration files.
//  Incorrect changes in [CORE] or [AUTO] sections can break the resource.
//──────────────────────────────────────────────────────────────────────────────

//──────────────────────────────────────────────────────────────────────────────
// Interface · Default Color Configuration                                      [EDIT]
//──────────────────────────────────────────────────────────────────────────────
// [INFO] Defines the base color palette and visual balance for the interface.
//        All values must be in hexadecimal format. Avoid RGB to prevent rendering issues.
//        Use the RESET button in UI to restore factory defaults.
//──────────────────────────────────────────────────────────────────────────────

// Primary and Secondary Colors
const defaultPrimaryColor       = "#0E151B"  // [EDIT] Base color for main UI backgrounds and buttons
const defaultPrimaryOpacity     = "0.2"      // [EDIT] Opacity level for primary color (0.0–1.0)
const defaultSecondaryColor     = "#0E151B"  // [EDIT] Secondary UI color for complementary elements
const defaultSecondaryOpacity   = "1.0"      // [EDIT] Full opacity for strong visibility

// Borders and Text
const defaultBorderColor        = "#00A3FF"  // [EDIT] Highlight color for UI borders and interactive elements
const defaultBorderOpacity      = "0.6"      // [EDIT] Semi-transparent level for UI borders
const defaultBorderRadius       = "1px"      // [EDIT] Defines corner roundness for UI boxes
const defaultTextColor          = "#FFFFFF"  // [EDIT] Default text color ensuring readability on dark UI
