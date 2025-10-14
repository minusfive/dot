#!/usr/bin/env bun

/**
 * Markdown Validation Script
 *
 * Validates markdown files according to project AGENTS.md guidelines:
 * - Heading hierarchy (H1→H2→H3→H4)
 * - Anchor link accuracy
 * - List formatting consistency
 * - Code block formatting
 *
 * Usage: bun run validate-markdown.ts <file-path>
 *
 * @author AI Agent - optimized for dotfiles configuration management
 */

interface ValidationResult {
  errors: number;
  warnings: number;
  messages: string[];
}

/**
 * Validates heading hierarchy in markdown file
 * @param lines - Array of file lines with line numbers
 * @returns Validation result for headings
 */
function validateHeadingHierarchy(lines: string[]): ValidationResult {
  const result: ValidationResult = { errors: 0, warnings: 0, messages: [] };
  let prevLevel = 0;

  lines.forEach((line, index) => {
    const lineNum = index + 1;
    const headingMatch = line.match(/^(#+)\s/);

    if (headingMatch) {
      const level = headingMatch[1].length;

      if (level > prevLevel + 1 && prevLevel > 0) {
        result.errors++;
        result.messages.push(
          `❌ Line ${lineNum}: Heading level H${level} jumps from H${prevLevel} (should increment by 1)`,
        );
      }

      prevLevel = level;
    }
  });

  if (result.errors === 0) {
    result.messages.push("✅ Heading hierarchy is correct");
  }

  return result;
}

/**
 * Validates list formatting (should use hyphens, not asterisks)
 * @param lines - Array of file lines
 * @returns Validation result for lists
 */
function validateListFormatting(lines: string[]): ValidationResult {
  const result: ValidationResult = { errors: 0, warnings: 0, messages: [] };

  lines.forEach((line, index) => {
    const lineNum = index + 1;
    if (/^\s*\* /.test(line)) {
      result.warnings++;
      result.messages.push(
        `! Line ${lineNum}: Use hyphens (-) for unordered lists instead of asterisks (*)`,
      );
    }
  });

  if (result.warnings === 0) {
    result.messages.push("✅ List formatting is consistent");
  }

  return result;
}

/**
 * Validates code blocks have language specification
 * @param lines - Array of file lines
 * @returns Validation result for code blocks
 */
function validateCodeBlocks(lines: string[]): ValidationResult {
  const result: ValidationResult = { errors: 0, warnings: 0, messages: [] };
  let inCodeBlock = false;

  lines.forEach((line, index) => {
    const lineNum = index + 1;
    const trimmed = line.trim();

    // Check for opening code block without language
    if (trimmed === "```" && !inCodeBlock) {
      result.warnings++;
      result.messages.push(
        `! Line ${lineNum}: Specify language for code blocks`,
      );
      inCodeBlock = true;
    } else if (trimmed.startsWith("```") && !inCodeBlock) {
      // Code block with language specified
      inCodeBlock = true;
    } else if (trimmed === "```" && inCodeBlock) {
      // Closing code block
      inCodeBlock = false;
    }
  });

  if (result.warnings === 0) {
    result.messages.push("✅ All code blocks specify languages");
  }

  return result;
}

/**
 * Checks for anchor links (basic detection)
 * @param lines - Array of file lines
 * @returns Validation result for anchor links
 */
function validateAnchorLinks(lines: string[]): ValidationResult {
  const result: ValidationResult = { errors: 0, warnings: 0, messages: [] };
  const anchorLinks: string[] = [];

  lines.forEach((line, index) => {
    const lineNum = index + 1;
    const anchorMatch = line.match(/\[.*?\]\(#.*?\)/g);

    if (anchorMatch) {
      anchorLinks.push(`   Line ${lineNum}: ${line.trim()}`);
    }
  });

  if (anchorLinks.length > 0) {
    result.messages.push(
      "i Found anchor links - manual verification recommended:",
    );
    result.messages.push(...anchorLinks);
  } else {
    result.messages.push("✅ No anchor links found");
  }

  return result;
}

/**
 * Main validation function
 * @param filePath - Path to markdown file to validate
 * @param exitOnError - Whether to call process.exit on validation errors (default: false for testing)
 * @returns Combined validation results
 */
async function validateMarkdownFile(
  filePath: string,
  exitOnError: boolean = false,
): Promise<ValidationResult> {
  const file = Bun.file(filePath);

  if (!(await file.exists())) {
    throw new Error(`File does not exist: ${filePath}`);
  }

  const content = await file.text();
  const lines = content.split("\n");
  const filename = filePath.split("/").pop() || filePath;

  console.log(`=== MARKDOWN VALIDATION: ${filename} ===`);
  console.log();

  const headingResult = validateHeadingHierarchy(lines);
  console.log("--- HEADING HIERARCHY ---");
  for (const msg of headingResult.messages) {
    console.log(msg);
  }
  console.log();

  const listResult = validateListFormatting(lines);
  console.log("--- LIST FORMATTING ---");
  for (const msg of listResult.messages) {
    console.log(msg);
  }
  console.log();

  const codeBlockResult = validateCodeBlocks(lines);
  console.log("--- CODE BLOCKS ---");
  for (const msg of codeBlockResult.messages) {
    console.log(msg);
  }
  console.log();

  const anchorResult = validateAnchorLinks(lines);
  console.log("--- ANCHOR LINKS ---");
  for (const msg of anchorResult.messages) {
    console.log(msg);
  }
  console.log();

  const totalResult: ValidationResult = {
    errors:
      headingResult.errors +
      listResult.errors +
      codeBlockResult.errors +
      anchorResult.errors,
    warnings:
      headingResult.warnings +
      listResult.warnings +
      codeBlockResult.warnings +
      anchorResult.warnings,
    messages: [],
  };

  console.log("=== SUMMARY ===");
  console.log(`Errors: ${totalResult.errors}`);
  console.log(`Warnings: ${totalResult.warnings}`);

  if (totalResult.errors > 0) {
    console.log("❌ Validation failed");
    if (exitOnError) {
      process.exit(1);
    }
  } else {
    console.log("✅ Validation passed");
  }

  return totalResult;
}

/**
 * Entry point - validates command line arguments and runs validation
 */
async function main(): Promise<void> {
  const args = Bun.argv.slice(2);

  if (args.length === 0) {
    console.error("Usage: bun run validate-markdown.ts <file-path>");
    process.exit(1);
  }

  const filePath = args[0];

  try {
    await validateMarkdownFile(filePath, true);
  } catch (error) {
    console.error(
      `Error: ${error instanceof Error ? error.message : "Unknown error"}`,
    );
    process.exit(1);
  }
}

// Run if this is the main module
if (import.meta.main) {
  await main();
}

export { validateMarkdownFile, type ValidationResult };
