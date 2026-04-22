import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';
import SockJS from 'sockjs-client';
import { IMessage, Stomp } from '@stomp/stompjs';

export interface ChatMessage {
  sender: string;
  role: string;
  content: string;
  timestamp?: string;
}

@Injectable({
  providedIn: 'root'
})
export class ChatService {
  private stompClient: any;
  private messages: ChatMessage[] = [];
  private messagesSubject = new BehaviorSubject<ChatMessage[]>([]);
  private connectedSubject = new BehaviorSubject<boolean>(false);

  messages$ = this.messagesSubject.asObservable();
  connected$ = this.connectedSubject.asObservable();

  constructor() {}

  connect(): void {
    const socket = new (SockJS as any)('http://localhost:8080/chat');
    this.stompClient = Stomp.over(socket);

    this.stompClient.connect({}, () => {
      this.stompClient.subscribe('/topic/messages', (message: IMessage) => {
        const msg: ChatMessage = JSON.parse(message.body);
        this.messages.push(msg);
        this.messagesSubject.next([...this.messages]);
      });

      this.connectedSubject.next(true);
    });
  }

  sendMessage(message: ChatMessage): boolean {
    if (this.stompClient && this.connectedSubject.value) {
      this.stompClient.send('/app/sendMessage', {}, JSON.stringify(message));
      return true;
    }
    return false;
  }
}
