//+------------------------------------------------------------------+
//| LOSERBOT.mq5                                                      |
//| Intentionally inverse ICT-style logic (for testing only)          |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Inverse ICT test EA - intentionally bad logic"

//--- includes
#include <Trade/Trade.mqh>

//--- trade object
CTrade trade;

//--- inputs
input double   EquityClosePct = 3.488;     // Close trade if profit % of balance
input int      StopLossPips   = 60;         // Fixed SL
input int      MaxTrades      = 20;         // Max simultaneous trades
input double   MinLot         = 0.05;
input double   MaxLot         = 1.00;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick                                                       |
//+------------------------------------------------------------------+
void OnTick()
{
   ManagePositions();
   DrawEquilibrium();
}

//+------------------------------------------------------------------+
//| Manage open positions                                             |
//+------------------------------------------------------------------+
void ManagePositions()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByIndex(i))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      double profit = PositionGetDouble(POSITION_PROFIT);
      ulong  ticket = (ulong)PositionGetInteger(POSITION_TICKET);

      //--- equity kill switch
      if(balance > 0.0 && (profit / balance) * 100.0 >= EquityClosePct)
      {
         trade.PositionClose(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Draw H1 equilibrium box                                           |
//+------------------------------------------------------------------+
void DrawEquilibrium()
{
   string boxName  = "EQ_BOX";
   string lineName = "EQ_LINE";

   ObjectDelete(0, boxName);
   ObjectDelete(0, lineName);

   int bars = 20;

   double high = iHigh(_Symbol, PERIOD_H1, 0);
   double low  = iLow(_Symbol, PERIOD_H1, 0);

   for(int i = 1; i < bars; i++)
   {
      high = MathMax(high, iHigh(_Symbol, PERIOD_H1, i));
      low  = MathMin(low,  iLow(_Symbol, PERIOD_H1, i));
   }

   double eq = (high + low) / 2.0;

   datetime t1 = iTime(_Symbol, PERIOD_H1, bars);
   datetime t2 = TimeCurrent();

   //--- equilibrium box
   ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, t1, high, t2, low);
   ObjectSetInteger(0, boxName, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, true);

   //--- equilibrium line
   ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, eq);
   ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrRed);
}
