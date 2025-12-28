#property strict
#property version   "1.00"
#property description "MT5 RSI Divergence Intraday EA"

#include <Trade/Trade.mqh>
CTrade trade;

// ================= INPUTS =================
input ENUM_TIMEFRAMES TF = PERIOD_M15;
input int    RSIPeriod  = 14;
input int    EMAPeriod  = 50;
input double RiskLots  = 0.10;
input int    StopLossPoints = 1200;
input int    TakeProfitPoints = 3333;

// ================= GLOBALS =================
int rsiHandle;
int emaHandle;
datetime lastBarTime = 0;

// ================= INIT =================
int OnInit()
{
   rsiHandle = iRSI(_Symbol, TF, RSIPeriod, PRICE_CLOSE);
   emaHandle = iMA(_Symbol, TF, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);

   if(rsiHandle == INVALID_HANDLE || emaHandle == INVALID_HANDLE)
   {
      Print("Indicator handle error");
      return INIT_FAILED;
   }
   return INIT_SUCCEEDED;
}

// ================= DEINIT =================
void OnDeinit(const int reason)
{
   IndicatorRelease(rsiHandle);
   IndicatorRelease(emaHandle);
}

// ================= TREND FILTER =================
bool BullTrend()
{
   double ema[1];
   CopyBuffer(emaHandle, 0, 0, 1, ema);
   return SymbolInfoDouble(_Symbol, SYMBOL_BID) > ema[0];
}

bool BearTrend()
{
   double ema[1];
   CopyBuffer(emaHandle, 0, 0, 1, ema);
   return SymbolInfoDouble(_Symbol, SYMBOL_BID) < ema[0];
}

// ================= RSI DIVERGENCE =================
bool BullishDivergence()
{
   double lows[3];
   double rsi[3];

   CopyLow(_Symbol, TF, 1, 3, lows);
   if(CopyBuffer(rsiHandle, 0, 1, 3, rsi) <= 0)
      return false;

   return (lows[0] < lows[1] && rsi[0] > rsi[1]);
}

bool BearishDivergence()
{
   double highs[3];
   double rsi[3];

   CopyHigh(_Symbol, TF, 1, 3, highs);
   if(CopyBuffer(rsiHandle, 0, 1, 3, rsi) <= 0)
      return false;

   return (highs[0] > highs[1] && rsi[0] < rsi[1]);
}

// ================= ON TICK =================
void OnTick()
{
   datetime barTime = iTime(_Symbol, TF, 0);
   if(barTime == lastBarTime) return;
   lastBarTime = barTime;

   if(PositionSelect(_Symbol)) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // BUY LOGIC
   if(BullTrend() && BullishDivergence())
   {
      trade.Buy(
         RiskLots,
         _Symbol,
         ask,
         ask - StopLossPoints * _Point,
         ask + TakeProfitPoints * _Point
      );
   }

   // SELL LOGIC
   if(BearTrend() && BearishDivergence())
   {
      trade.Sell(
         RiskLots,
         _Symbol,
         bid,
         bid + StopLossPoints * _Point,
         bid - TakeProfitPoints * _Point
      );
   }
}
