import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Observable } from 'rxjs';
import { ChatService, ChatMessage } from './services/chat.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class App implements OnInit {
  sender = '';
  role = 'CLIENT';
  content = '';
  messages$: Observable<ChatMessage[]>;
  connected$: Observable<boolean>;

  constructor(private chatService: ChatService) {
    this.messages$ = this.chatService.messages$;
    this.connected$ = this.chatService.connected$;
  }

  ngOnInit(): void {
    this.chatService.connect();
  }

  send(): void {
    if (!this.sender.trim() || !this.content.trim()) return;

    const sent = this.chatService.sendMessage({
      sender: this.sender,
      role: this.role,
      content: this.content
    });

    if (sent) {
      this.content = '';
    }
  }
}
