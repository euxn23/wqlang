#include "stdio.h"
#include "string.h"
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
  int m = strlen(patt);
  char back[m];
  int i = 0, j = -1;
  back[0] = -1;

  while(i < m-1) {
    if((j >= 0) && (patt[i] != patt[j])){
      j = back[j];
    }
    i++;
    j++;
    back[i] = j;
  }

  for(i=0;i<m;i++){
    printf("%d\n", back[i]);
  }
  printf("%p\n", patt);
  // printf("%s\n", src);
}

void kmp_match(char* text, char* patt){

}
