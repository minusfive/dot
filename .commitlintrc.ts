import type { UserConfig } from "@commitlint/types";
import { RuleConfigSeverity } from "@commitlint/types";

const Configuration: UserConfig = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "header-max-length": [RuleConfigSeverity.Error, "always", 50],
    "body-max-line-length": [RuleConfigSeverity.Error, "always", 72],
    "footer-max-line-length": [RuleConfigSeverity.Error, "always", 72],
  },
};

export default Configuration;
