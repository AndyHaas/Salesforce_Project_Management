const path = require("path");
const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  // v8 coverage often reports 0% for LWC-compiled sources; babel + istanbul aligns with the transformer pipeline.
  coverageProvider: "babel",
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
  moduleNameMapper: {
    "^lightning/actions$": path.join(__dirname, "jest.mocks/lightning-actions.js"),
    "^lightning/modal$": path.join(__dirname, "jest.mocks/lightning-modal.js")
  }
};
