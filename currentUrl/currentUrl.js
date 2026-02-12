import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';

export default class CurrentUrl extends LightningElement {
    @api currentUrl;

    connectedCallback() {
        this.currentUrl = window.location.href;
        this.dispatchEvent(
            new FlowAttributeChangeEvent('currentUrl', this.currentUrl)
        );
    }
}