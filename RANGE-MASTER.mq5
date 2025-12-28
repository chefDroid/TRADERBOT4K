//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ICT Doyle 15M FVG Equilibrium Scalper                             |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//================ INPUTS =================
input double RiskPercent     = 2.0;
input int    TradeStartHour  = 7;
input int    TradeEndHour    = 16;
input double StopLossPips    = 45.0;
input ENUM_TIMEFRAMES FVG_TF = PERIOD_M15;
input ENUM_TIMEFRAMES BiasTF = PERIOD_H1;

//================ GLOBALS =================
datetime lastTradeTime = 0;

//+------------------------------------------------------------------+
//| Session filter                                                   |
//+------------------------------------------------------------------+
bool IsTradingSession()
{
   datetime now = TimeCurrent();
   MqlDateTime t;
   TimeToStruct(now, t);

   if(t.hour >= TradeStartHour && t.hour <= TradeEndHour)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| HTF Bias (Displacement)                                          |
//+------------------------------------------------------------------+
int GetBias()
{
   double open  = iOpen(_Symbol, BiasTF, 1);
   double close = iClose(_Symbol, BiasTF, 1);

   if(close > open)
      return 1;   // bullish
   if(close < open)
      return -1;  // bearish

   return 0;
}

//+------------------------------------------------------------------+
//| Lot calculation                                                  |
//+------------------------------------------------------------------+
double CalculateLot()
{
   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * (RiskPercent / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0 || tickSize <= 0)
      return 0.0;

   double stopPoints = StopLossPips * 10;
   double lot = riskMoney / ((stopPoints * tickValue) / tickSize);

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   lot = MathMax(minLot, MathMin(maxLot, lot));
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Detect 15m Fair Value Gap                                        |
//+------------------------------------------------------------------+
bool GetFVG(double &eq, bool bullish)
{
   double high2 = iHigh(_Symbol, FVG_TF, 2);
   double low2  = iLow(_Symbol, FVG_TF, 2);
   double high1 = iHigh(_Symbol, FVG_TF, 1);
   double low1  = iLow(_Symbol, FVG_TF, 1);
   double high0 = iHigh(_Symbol, FVG_TF, 0);
   double low0  = iLow(_Symbol, FVG_TF, 0);

   // Bullish FVG
   if(bullish && low0 > high2)
   {
      eq = (low0 + high2) / 2.0;
      return true;
   }

   // Bearish FVG
   if(!bullish && high0 < low2)
   {
      eq = (high0 + low2) / 2.0;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Main Tick                                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsTradingSession())
      return;

   if(PositionSelect(_Symbol))
      return;

   int bias = GetBias();
   if(bias == 0)
      return;

   double eqPrice;
   bool fvgFound = GetFVG(eqPrice, bias == 1);
   if(!fvgFound)
      return;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot   = CalculateLot();
   if(lot <= 0)
      return;

   double sl, tp;

   // BUY from demand FVG equilibrium
   if(bias == 1 && price <= eqPrice)
   {
      sl = eqPrice - StopLossPips * _Point * 10;
      tp = eqPrice + StopLossPips * 2 * _Point * 10;

      trade.Buy(lot, _Symbol, price, sl, tp, "ICT FVG Buy");
   }

   // SELL from supply FVG equilibrium
   if(bias == -1 && price >= eqPrice)
   {
      sl = eqPrice + StopLossPips * _Point * 10;
      tp = eqPrice - StopLossPips * 2 * _Point * 10;

      trade.Sell(lot, _Symbol, price, sl, tp, "ICT FVG Sell");
   }
}
