/**
 * Jest stub for lightning/modal (portalMessageComposeModal extends LightningModal).
 */
import { LightningElement, api } from "lwc";

class LightningModal extends LightningElement {
  @api
  close() {
    return Promise.resolve();
  }
}

LightningModal.open = jest.fn().mockResolvedValue(undefined);

export default LightningModal;
