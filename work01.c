#include "stdio.h"
// #include "string.h"
// #include "stdlib.h"

void kmp_init(char* patt);

void kmp_exec(char* text, char* patt);

int main(void)
{
  char patt[] = "abcabcab";
  kmp_init(patt);
  return 0;
}

void kmp_init(char* patt){
  int len = sizeof(patt);
  char back[len];
  int i = 0, j = -1;

  while(j >= 0) {
    if(patt[i] != patt[j]){
      j++;
      j = back[j];
    }
    i++;
  }




  printf("%d\n", len);
  printf("%s\n", patt);
  printf("%p\n", patt);
  // printf("%s\n", src);
}

void kmp_exec(char* text, char* patt){

}
