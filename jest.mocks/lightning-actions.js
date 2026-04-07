/**
 * Jest stub for lightning/actions (platform module; not resolved by sfdx-lwc-jest for all imports).
 */
export class CloseActionScreenEvent extends CustomEvent {
  constructor() {
    super("lightning__actionsclosescreen", { bubbles: true, composed: true });
  }
}
