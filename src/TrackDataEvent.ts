import { Event } from 'event-target-shim/index';

export type TrackEventDataType = string | ArrayBuffer | Blob;

type DATA_EVENTS = 'data' | 'audio' | 'video' | 'text';

interface TrackDataEventInitDict extends Event.EventInit {
    data: TrackEventDataType;
}

/**
 * @eventClass
 * This event is fired whenever the RTCMediaSteam/RTCMediaSteamTracker callback data.
 * @param {DATA_EVENTS} type - The type of event.
 * @param {TrackDataEventInitDict} eventInitDict - The event init properties.
 * @see
 * {@link https://developer.mozilla.org/en-US/docs/Web/API/RTCDataChannel/message_event#event_type MDN} for details.
 */
export default class TrackDataEvent<TEventType extends DATA_EVENTS> extends Event<TEventType> {
    /** @eventProperty */
    data: TrackEventDataType;
    constructor(type: TEventType, eventInitDict: TrackDataEventInitDict) {
        super(type, eventInitDict);
        this.data = eventInitDict.data;
    }
}
