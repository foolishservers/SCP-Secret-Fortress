public Action Command_Queue(int client, int args)
{
	if(client == 0) return Plugin_Handled;

	ShowQueueMenu(client);
	return Plugin_Handled;
}

void ShowQueueMenu(int client)
{
	Menu menu = new Menu(Menu_QueueH);
	menu.SetTitle("SCP 큐 메뉴 (현재 큐 포인트: %d)", Client[client].QueuePoints);

	char buffer[128];
	Format(buffer, sizeof(buffer), "큐 상태: [%s]", Client[client].QueueEnabled ? "켜짐" : "꺼짐");
	menu.AddItem("toggle", buffer);

	menu.AddItem("blacklist", "SCP 플레이 블랙리스트 설정");
	menu.AddItem("ranking", "대기열 순위 확인 (상위 7명)");

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_QueueH(Menu menu, MenuAction action, int client, int choice)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(choice, info, sizeof(info));

		if(StrEqual(info, "toggle"))
		{
			Client[client].QueueEnabled = !Client[client].QueueEnabled;
			PrintToChat(client, "\x04[SCP]\x01 큐가 \x03%s\x01되었습니다.", Client[client].QueueEnabled ? "활성화" : "비활성화");
			ShowQueueMenu(client);
		}
		else if(StrEqual(info, "blacklist"))
		{
			ShowBlacklistMenu(client, 0);
		}
		else if(StrEqual(info, "ranking"))
		{
			ShowQueueRankMenu(client);
		}
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void ShowQueueRankMenu(int client)
{
	Menu menu = new Menu(Menu_QueueRankH);
	menu.SetTitle("SCP 큐 포인트 순위");

	int[] players = new int[MaxClients + 1];
	int count = 0;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && Client[i].QueueEnabled && GetClientTeam(i) > 1)
		{
			players[count++] = i;
		}
	}

	// Sort players by QueuePoints descending (simple bubble sort)
	for(int i = 0; i < count - 1; i++)
	{
		for(int j = 0; j < count - i - 1; j++)
		{
			if(Client[players[j]].QueuePoints < Client[players[j+1]].QueuePoints)
			{
				int temp = players[j];
				players[j] = players[j+1];
				players[j+1] = temp;
			}
		}
	}

	int limit = count > 7 ? 7 : count;
	char display[128];
	if(limit == 0)
	{
		menu.AddItem("", "현재 대기열에 아무도 없습니다.", ITEMDRAW_DISABLED);
	}
	else
	{
		for(int i = 0; i < limit; i++)
		{
			Format(display, sizeof(display), "%N (%d점)", players[i], Client[players[i]].QueuePoints);
			menu.AddItem("", display, ITEMDRAW_DISABLED);
		}
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_QueueRankH(Menu menu, MenuAction action, int client, int choice)
{
	if(action == MenuAction_Cancel && choice == MenuCancel_ExitBack)
	{
		ShowQueueMenu(client);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void ShowBlacklistMenu(int client, int position)
{
	Menu menu = new Menu(Menu_BlacklistH);
	menu.SetTitle("SCP 블랙리스트 설정 (체크 시 플레이 안함)");

	char info[32];
	char display[128];
	ClassEnum classInfo;

	// Loop through all classes and add SCPs to menu
	for(int i = 1; i < 2048; i++) // Using a safe upper bound
	{
		if(!Classes_GetByIndex(i, classInfo)) break;

		// Only allow blacklisting SCPs that are playable (in "set_scp" preset)
		if(classInfo.Group == 0 && Gamemode_IsClassInPreset("set_scp", classInfo.Name))
		{
			IntToString(i, info, sizeof(info));
			
			bool isBlacklisted = (Client[client].Blacklist.FindValue(i) != -1);
			Format(display, sizeof(display), "[%s] %s", isBlacklisted ? "X" : " ", classInfo.Display);

			menu.AddItem(info, display);
		}
	}

	menu.ExitBackButton = true;
	menu.DisplayAt(client, position, MENU_TIME_FOREVER);
}

public int Menu_BlacklistH(Menu menu, MenuAction action, int client, int choice)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(choice, info, sizeof(info));
		int class_idx = StringToInt(info);

		int listIndex = Client[client].Blacklist.FindValue(class_idx);
		if(listIndex != -1)
		{
			Client[client].Blacklist.Erase(listIndex);
			PrintToChat(client, "\x04[SCP]\x01 해당 SCP를 블랙리스트에서 \x04제거\x01했습니다.");
		}
		else
		{
			Client[client].Blacklist.Push(class_idx);
			PrintToChat(client, "\x04[SCP]\x01 해당 SCP를 블랙리스트에 \x02추가\x01했습니다.");
		}

		ShowBlacklistMenu(client, menu.Selection);
	}
	else if(action == MenuAction_Cancel && choice == MenuCancel_ExitBack)
	{
		ShowQueueMenu(client);
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void Queue_AddPointsToUnselected()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i))
		{
			ClassEnum classInfo;
			bool isSCP = false;
			if(Classes_GetByIndex(Client[i].Class, classInfo))
			{
				if(classInfo.Group == 0) isSCP = true;
			}

			if(!isSCP)
			{
				Client[i].QueuePoints += 10;
				PrintToChat(i, "\x04[SCP]\x01 이번 라운드에 SCP로 선택되지 않아 큐 포인트 \x0310점\x01이 지급되었습니다. (현재: %d)", Client[i].QueuePoints);
			}
		}
	}
}
